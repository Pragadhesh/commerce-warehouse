#!/bin/bash
# Loads the fiction-retail sample extract into the raw schema created by
# 01_schema.sql. Runs automatically on first container start via Postgres's
# docker-entrypoint-initdb.d mechanism.
#
# Data files under data/ are a referentially-consistent subset of the full
# source dataset (~700k rows across all tables) sized for a fast local spin-up:
# dimension tables (products, suppliers, warehouses, inventory, promotions)
# are loaded in full, and a sample of customers is loaded along with every
# order, order item, shipment, and return that belongs to them.

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    \copy raw.customers  FROM '/docker-entrypoint-initdb.d/data/customers.csv'  WITH (FORMAT csv, HEADER true)
    \copy raw.suppliers  FROM '/docker-entrypoint-initdb.d/data/suppliers.csv'  WITH (FORMAT csv, HEADER true)
    \copy raw.warehouses FROM '/docker-entrypoint-initdb.d/data/warehouses.csv' WITH (FORMAT csv, HEADER true)
    \copy raw.products   FROM '/docker-entrypoint-initdb.d/data/products.csv'   WITH (FORMAT csv, HEADER true)
    \copy raw.inventory  FROM '/docker-entrypoint-initdb.d/data/inventory.csv'  WITH (FORMAT csv, HEADER true)
    \copy raw.promotions FROM '/docker-entrypoint-initdb.d/data/promotions.csv' WITH (FORMAT csv, HEADER true)
    \copy raw.orders      FROM '/docker-entrypoint-initdb.d/data/orders.csv'      WITH (FORMAT csv, HEADER true)
    \copy raw.order_items FROM '/docker-entrypoint-initdb.d/data/order_items.csv' WITH (FORMAT csv, HEADER true)
    \copy raw.shipments   FROM '/docker-entrypoint-initdb.d/data/shipments.csv'   WITH (FORMAT csv, HEADER true)
    \copy raw.returns     FROM '/docker-entrypoint-initdb.d/data/returns.csv'     WITH (FORMAT csv, HEADER true)
EOSQL
