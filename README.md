# commerce-warehouse

Analytics warehouse for the commerce data platform: raw order/customer/product
extracts, the staging and mart models built on top of them, and the local
Postgres environment used to develop and test changes before they run against
the real warehouse.

## What's in here

```
docker-compose.yml     Local Postgres 16 instance
init/                  Schema DDL + seed data, applied on first container start
models/
  staging/             1:1 cleaned views over each raw source table
  marts/                Business-logic models built on staging (customer,
                         product/inventory, and fulfillment views)
dbt_project.yml         dbt project config (models are dbt-style SQL; see
                         "Running dbt" below for current status)
```

### Data model

The raw layer is a five-table order/fulfillment schema plus supporting
dimensions, loaded into the `raw` Postgres schema:

- `customers` — customer master data (id, contact info, segment, geography)
- `orders` — one row per order, links to `customers` and optionally a `promotions` row
- `order_items` — line items within an order, links to `orders` and `products`
- `products` — product catalog, links to `suppliers`
- `suppliers` — vendor master data
- `inventory` — per-product, per-warehouse stock position
- `warehouses` — fulfillment center master data
- `shipments` — shipment records against orders
- `returns` — return/refund records against orders
- `promotions` — promo code catalog

```
customers ──< orders ──< order_items >── products >── suppliers
                │                             │
                │                        inventory >── warehouses
                │
           shipments >── warehouses
                │
            returns
                │
          promotions (via orders.promo_id)
```

No foreign keys are enforced at the database level — this mirrors how the
data arrives from the upstream extract (append-only, occasionally
out-of-order), and referential integrity is checked at the staging layer via
dbt tests instead.

The `init/data/` seed set is a referentially-consistent sample, not the full
production volume: dimension tables (`products`, `suppliers`, `warehouses`,
`inventory`, `promotions`) are loaded in full, and a sample of customers is
loaded along with every order, order item, shipment, and return that belongs
to them. This keeps `docker compose up` fast while still exercising every
join in the model layer against real data.

## Local setup

Requires Docker and Docker Compose.

```bash
docker compose up -d
```

This starts a single Postgres 16 container (`commerce-warehouse-db`) and, on
first boot only, runs the scripts in `init/` in order:

1. `01_schema.sql` creates the `raw` schema and its 10 tables
2. `02_load_data.sh` loads the CSVs in `init/data/` into those tables

Connection details:

| | |
|---|---|
| Host | `localhost` |
| Port | `5433` (mapped from the container's 5432, to avoid clashing with a local Postgres install) |
| Database | `commerce_warehouse` |
| User / password | `warehouse` / `warehouse` |

```bash
psql "postgresql://warehouse:warehouse@localhost:5433/commerce_warehouse"
```

Override the default credentials by setting `POSTGRES_USER`,
`POSTGRES_PASSWORD`, and `POSTGRES_DB` in a local `.env` file before starting
the stack (see `docker-compose.yml`).

To reset the database to a clean state (re-running the init scripts on next
start):

```bash
docker compose down -v
docker compose up -d
```

## Model layer

Models under `models/` are written in dbt style (`{{ source(...) }}`,
`{{ ref(...) }}`, `schema.yml` docs and tests) so they read the same way they
will once wired into the team's shared dbt project. `dbt_project.yml` and
`schema.yml` are checked in for that reason, but this repo does not currently
run `dbt` itself — the local stack only provisions and seeds the raw schema.

To run the models against the local stack, install `dbt-postgres` and point
a profile at the container:

```bash
pip install dbt-postgres
```

`~/.dbt/profiles.yml`:

```yaml
commerce_warehouse:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      port: 5433
      user: warehouse
      password: warehouse
      dbname: commerce_warehouse
      schema: analytics
      threads: 4
```

```bash
dbt run
dbt test
```

- `models/staging/` — one view per raw source table: renames, casts, and a
  handful of derived columns (e.g. `line_item_amount`, `transit_days`). No
  joins, no business logic.
- `models/marts/`:
  - `customer_profile` — one row per customer with lifetime order stats;
    feeds the CRM sync and segmentation dashboards.
  - `customer_order_summary` — revenue and order volume by segment and
    country, for the quarterly business review.
  - `product_supplier_inventory` — stock position and supplier attribution
    per product, for merchandising's reorder-planning workflow.
  - `order_fulfillment_performance` — shipment and return performance by
    carrier and warehouse, for the logistics carrier scorecard.

## DataHub ingestion

To bring this warehouse's schema and lineage into DataHub, ingest the
Postgres instance directly with the `postgres` source. Point it at the local
stack (or the real warehouse, adjusting host/port/credentials) with a recipe
along these lines:

```yaml
# postgres_ingest.yaml
source:
  type: postgres
  config:
    host_port: "localhost:5433"
    username: warehouse
    password: warehouse
    database: commerce_warehouse
    include_views: true
    schema_pattern:
      allow:
        - "raw"
        - "analytics"

sink:
  type: datahub-rest
  config:
    server: "http://localhost:8080"
```

```bash
pip install 'acryl-datahub[postgres]'
datahub ingest -c postgres_ingest.yaml
```

This picks up both the `raw` tables and, once `dbt run` has materialized
them, the `analytics` schema views — giving column-level lineage for
anything Postgres itself can see (i.e. the views' `SELECT` definitions).

Once the model layer is running as a real dbt project (with `dbt docs
generate` producing `manifest.json` / `catalog.json`), switching to the
`dbt` source instead of `postgres` will additionally surface model
descriptions, tests, and `ref()`/`source()`-based lineage as authored in
`schema.yml`, rather than lineage inferred from view SQL.
