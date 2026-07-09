-- Raw landing schema for the fiction-retail source extract.
--
-- These tables mirror the upstream operational tables as delivered by the
-- extract job, column-for-column. No renaming, casting, or business logic
-- happens here -- that's the job of the staging models in models/staging/.
--
-- Foreign keys are intentionally NOT enforced. This is a landing layer fed
-- by an external extract process; late-arriving or out-of-order files are
-- expected, and we don't want a load to fail because, say, a shipment row
-- arrived before its parent order. Referential integrity is checked at the
-- staging layer via dbt tests instead (see models/staging/schema.yml).

create schema if not exists raw;

create table raw.customers (
    customer_id         text primary key,
    name                text,
    email               text,
    phone               text,
    signup_date         date,
    country             text,
    state               text,
    city                text,
    customer_segment    text
);

create table raw.suppliers (
    supplier_id             text primary key,
    name                    text,
    country                 text,
    contract_start_date     date,
    status                  text
);

create table raw.warehouses (
    warehouse_id        text primary key,
    name                text,
    city                text,
    state               text,
    country             text,
    capacity_units      integer,
    opened_date         date
);

create table raw.products (
    product_id          text primary key,
    name                text,
    category            text,
    brand               text,
    price               numeric(12, 2),
    weight_kg           numeric(10, 3),
    supplier_id         text
);

create table raw.inventory (
    inventory_id            text primary key,
    product_id              text,
    warehouse_id            text,
    quantity_on_hand        integer,
    reserved_quantity       integer,
    reorder_threshold       integer,
    last_restocked_date     date
);

create table raw.promotions (
    promo_id                text primary key,
    promo_code              text,
    description             text,
    discount_pct            integer,
    valid_from              date,
    valid_until             date,
    applies_to_category     text,
    max_uses                integer,
    status                  text
);

create table raw.orders (
    order_id            text primary key,
    customer_id         text,
    order_date          date,
    order_status        text,
    total_amount        numeric(12, 2),
    payment_method      text,
    shipping_country    text,
    promo_id            text
);

create table raw.order_items (
    order_item_id       text primary key,
    order_id            text,
    product_id          text,
    quantity            integer,
    unit_price          numeric(12, 2),
    discount_pct        integer
);

create table raw.shipments (
    shipment_id         text primary key,
    order_id            text,
    warehouse_id        text,
    carrier             text,
    tracking_number     text,
    shipped_date        date,
    delivered_date      date,
    shipment_state      text
);

create table raw.returns (
    return_id               text primary key,
    order_id                text,
    product_id              text,
    return_date             date,
    refund_amount           numeric(12, 2),
    return_reason_code      text,
    processed_by            text
);
