# commerce-warehouse

Analytics warehouse for the commerce data platform, structured the way a
real infrastructure repo would be: **one top-level folder per platform**,
each holding that platform's own provisioning code (SQL DDL for Postgres,
a seed script for MongoDB, Terraform for S3/Kafka/Metabase), plus the
DataHub recipe that ingests it. There is no shared orchestration script --
each platform folder is self-contained.

The point of the multi-platform spread (relational warehouse, NoSQL store,
event stream, data lake, BI layer) is to be a realistic target for tools
like [Blast](https://github.com/Pragadhesh/Blast): edit a SQL file or a
Terraform resource in any one of these folders, open a PR, and check what
the DataHub lineage graph says broke downstream.

## Layout

```
postgres/     SQL: schema DDL, seed data, view mirror of the dbt models
dbt/          dbt project: staging + mart models -- the main file you'll edit for a demo
mongodb/      Seed script for the product_reviews collection
s3/           Terraform: the raw-landing bucket (against MinIO locally)
kafka/        Terraform: the order-events topic
metabase/     Terraform: the warehouse database connection
docker-compose.yml   Runs all five platforms locally
```

Each of `postgres/`, `dbt/`, `mongodb/`, `s3/`, `kafka/`, `metabase/` also
holds its own `datahub_ingest.yaml` -- the recipe that tells DataHub about
that specific platform.

```
 ┌───────────┐  ┌───────────┐  ┌───────────┐
 │    s3/    │  │  mongodb/ │  │   kafka/  │   <- provisioned independently
 │ terraform │  │   init/   │  │ terraform │      (S3 bucket, Mongo seed,
 └─────┬─────┘  └─────┬─────┘  └─────┬─────┘       Kafka topic)
       │              │              │
       ▼              ▼              ▼
 ┌──────────────────────────────────────────┐
 │              postgres/init/                │   <- raw.* tables (schema DDL
 │   raw.* tables, self-seeded from CSVs       │      + seed data); product_reviews
 └──────────────────────┬───────────────────┘      and order_status_events tables
                         │                          exist here too but are meant
                         │ postgres/init/            to be landed from Mongo/Kafka
                         │ 03_create_views.sql        (schema only right now)
                         ▼
 ┌──────────────────────────────────────────┐
 │        dbt/models/staging -> marts          │   <- the file you edit for a demo
 └──────────────────────┬───────────────────┘
                         │
                         ▼
                   metabase/terraform
                  (dashboards on the marts)

 Each box above also has its own datahub_ingest.yaml -- DataHub stitches
 all of them into one lineage graph (see "DataHub ingestion" below).
```

### Data model

The relational core is a ten-table order/fulfillment schema in the `raw`
Postgres schema, plus two tables whose *schema* lives in Postgres but whose
*data* belongs to other platforms:

- `customers`, `orders`, `order_items`, `products`, `suppliers`,
  `inventory`, `warehouses`, `shipments`, `returns`, `promotions` -- the
  CSV extract, self-seeded on container boot.
- `product_reviews` -- schema only; real data is MongoDB's `product_reviews`
  collection (`mongodb/init/init-reviews.js`).
- `order_status_events` -- schema only; real data would come from the
  `order-events` Kafka topic (`kafka/terraform/`).

```
customers ──< orders ──< order_items >── products >── suppliers
                │                             │
                │                        inventory >── warehouses
                │
           shipments >── warehouses
                │
            returns

           promotions (via orders.promo_id)

    product_reviews >── products        (MongoDB-sourced)
    order_status_events >── orders      (Kafka-sourced)
```

No foreign keys are enforced at the database level -- this mirrors how the
data arrives from the upstream extract (append-only, occasionally
out-of-order), and referential integrity is checked at the dbt staging
layer instead.

## Local setup

Requires Docker and Docker Compose.

```bash
docker compose up -d
```

This starts five containers: `commerce-warehouse-db` (Postgres),
`commerce-warehouse-mongo` (MongoDB), `commerce-warehouse-minio` (MinIO),
`commerce-warehouse-kafka` (Kafka, single-node KRaft mode), and
`commerce-warehouse-metabase` (Metabase).

Postgres and MongoDB seed themselves automatically on first boot (via
`docker-entrypoint-initdb.d`, from `postgres/init/` and `mongodb/init/`
respectively) -- at that point every dbt model already exists as a
queryable Postgres view (`postgres/init/03_create_views.sql`), no dbt
install required. MinIO and Kafka come up empty; provision them with the
Terraform in `s3/terraform/` and `kafka/terraform/` (see each folder's
`main.tf`).

Connection details:

| Service | Host | Port | Notes |
|---|---|---|---|
| Postgres | `localhost` | `5433` | user/pass `warehouse` / `warehouse`, db `commerce_warehouse` |
| MongoDB | `localhost` | `27017` | db `commerce_reviews` |
| MinIO API | `localhost` | `9000` | key/secret `minioadmin` / `minioadmin` |
| MinIO console | `localhost` | `9001` | same credentials, browser UI |
| Kafka | `localhost` | `9094` | 9092 is reserved for DataHub's own broker |
| Metabase | `localhost` | `3000` | complete first-run setup in the browser first |

```bash
psql "postgresql://warehouse:warehouse@localhost:5433/commerce_warehouse"
```

Override default credentials via a local `.env` file (copy `.env.example`)
before starting the stack.

To reset everything to a clean state (re-running all init scripts on next
start):

```bash
docker compose down -v
docker compose up -d
```

## postgres/

`postgres/init/` is mounted straight into the Postgres container as
`docker-entrypoint-initdb.d`, so its numbered files run in order on first
boot: `01_schema.sql` (raw tables), `02_load_data.sh` (loads
`init/data/*.csv`), `03_create_views.sql` (a plain-SQL mirror of every dbt
model, kept in lockstep -- see its header comment). `postgres/datahub_ingest.yaml`
ingests both the raw tables and those views.

## dbt/

This is the model layer, and the folder you'll spend the most time editing
for a demo -- change a column here, open a PR, and see what Blast says
breaks downstream.

```bash
cd dbt
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
dbt docs generate
```

- `models/staging/` -- one view per raw source table: renames, casts, and a
  handful of derived columns. No joins, no business logic. Includes
  `stg_product_reviews` and `stg_order_events`, whose schemas track the
  MongoDB collection and Kafka topic respectively rather than the CSV
  extract.
- `models/marts/`:
  - `customer_profile` -- one row per customer with lifetime order stats;
    feeds the CRM sync and segmentation dashboards.
  - `customer_order_summary` -- revenue and order volume by segment and
    country, for the quarterly business review.
  - `product_supplier_inventory` -- stock position and supplier attribution
    per product, for merchandising's reorder-planning workflow. Fully
    isolated from the customer/order side of the warehouse.
  - `order_fulfillment_performance` -- shipment and return performance by
    carrier and warehouse, for the logistics carrier scorecard.
  - `product_review_summary` -- average rating and review volume per
    product. The clearest place to see a NoSQL-sourced breaking change land.

## mongodb/

`mongodb/init/init-reviews.js` seeds the `product_reviews` collection
automatically on first boot, the same way `postgres/init/` does for
Postgres. `mongodb/datahub_ingest.yaml` ingests it as its own platform node.

## s3/, kafka/, metabase/ (Terraform)

These three don't have a file-based self-seed mechanism the way Postgres
and MongoDB do -- in a real deployment they'd be actual cloud/managed
resources, so they're provisioned as Terraform instead:

- **`s3/terraform/`** -- creates the `commerce-raw-landing` bucket and
  uploads the seed CSVs, against MinIO locally via the AWS provider's
  endpoint-override support (a real, common pattern for S3-compatible
  local testing -- swap the endpoint for real AWS and this becomes
  production Terraform unchanged).
- **`kafka/terraform/`** -- declares the `order-events` topic (partitions,
  retention) as code via the `Mongey/kafka` provider.
- **`metabase/terraform/`** -- declares the warehouse database connection
  via the community `flovouin/metabase` provider. This provider is far
  less battle-tested than the other two -- verify its resource schema
  against the registry before relying on it; the manual equivalent
  (Admin -> Databases -> Add a database, host `warehouse-db`, port `5432`)
  always works as a fallback.

Each folder's `main.tf` has more detail. None of these have been applied in
this environment -- review the provider/variable files before running
`terraform init && terraform apply` for real.

## DataHub ingestion

Ingest each platform independently against a running DataHub instance, from
the repo root:

```bash
export DATAHUB_SERVER=http://localhost:8080
export DATAHUB_TOKEN=...

pip install 'acryl-datahub[postgres,dbt,mongodb,s3,kafka,metabase]'

datahub ingest -c postgres/datahub_ingest.yaml
datahub ingest -c mongodb/datahub_ingest.yaml
datahub ingest -c s3/datahub_ingest.yaml
datahub ingest -c kafka/datahub_ingest.yaml
datahub ingest -c metabase/datahub_ingest.yaml

datahub ingest -c dbt/datahub_ingest.yaml
```

The result is one graph spanning six platform types -- postgres, dbt,
mongodb, s3, kafka, metabase -- which is what makes this a meaningfully
harder (and more realistic) target for blast-radius tooling than a
single-database demo: a breaking change has to be traced through more than
one kind of system to get the full picture, exactly like it would in
production.
