-- Materializes the dbt-style models under models/ as real Postgres views,
-- in the public schema, so DataHub's postgres source can discover them and
-- parse view->view / table->view lineage from their SQL definitions.
-- Generated from models/**/*.sql -- if you change a model, regenerate this
-- file rather than hand-editing it, or the two will drift.

-- ==================== staging views ====================

-- Light cleanup of the raw customers extract: stable column names and
-- typing only, no business logic. Downstream marts should build on this
-- model rather than querying raw.customers directly.
create view stg_customers as
with source as (

    select * from raw.customers

),

renamed as (

    select
        customer_id,
        name                as customer_name,
        email               as customer_email,
        phone               as customer_phone,
        signup_date,
        country,
        state,
        city,
        customer_segment

    from source

)

select * from renamed;

create view stg_orders as
with source as (

    select * from raw.orders

),

renamed as (

    select
        order_id,
        customer_id,
        order_date,
        order_status,
        total_amount,
        payment_method,
        shipping_country,
        promo_id

    from source

)

select * from renamed;

create view stg_order_items as
with source as (

    select * from raw.order_items

),

renamed as (

    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        discount_pct,
        round(quantity * unit_price * (1 - discount_pct / 100.0), 2) as line_item_amount

    from source

)

select * from renamed;

create view stg_products as
with source as (

    select * from raw.products

),

renamed as (

    select
        product_id,
        name            as product_name,
        category        as product_category,
        brand,
        price           as list_price,
        weight_kg,
        supplier_id

    from source

)

select * from renamed;

create view stg_suppliers as
with source as (

    select * from raw.suppliers

),

renamed as (

    select
        supplier_id,
        name        as supplier_name,
        country     as supplier_country,
        contract_start_date,
        status      as supplier_status

    from source

)

select * from renamed;

create view stg_warehouses as
with source as (

    select * from raw.warehouses

),

renamed as (

    select
        warehouse_id,
        name        as warehouse_name,
        city,
        state,
        country,
        capacity_units,
        opened_date

    from source

)

select * from renamed;

create view stg_inventory as
with source as (

    select * from raw.inventory

),

renamed as (

    select
        inventory_id,
        product_id,
        warehouse_id,
        quantity_on_hand,
        reserved_quantity,
        quantity_on_hand - reserved_quantity as quantity_available,
        reorder_threshold,
        last_restocked_date

    from source

)

select * from renamed;

create view stg_shipments as
with source as (

    select * from raw.shipments

),

renamed as (

    select
        shipment_id,
        order_id,
        warehouse_id,
        carrier,
        tracking_number,
        shipped_date,
        delivered_date,
        shipment_state,
        case
            when delivered_date is not null
                then delivered_date - shipped_date
        end as transit_days

    from source

)

select * from renamed;

create view stg_returns as
with source as (

    select * from raw.returns

),

renamed as (

    select
        return_id,
        order_id,
        product_id,
        return_date,
        refund_amount,
        return_reason_code,
        processed_by

    from source

)

select * from renamed;

create view stg_promotions as
with source as (

    select * from raw.promotions

),

renamed as (

    select
        promo_id,
        promo_code,
        description     as promo_description,
        discount_pct,
        valid_from,
        valid_until,
        applies_to_category,
        max_uses,
        status          as promo_status

    from source

)

select * from renamed;

-- ==================== mart views ====================

-- One row per customer, feeding the CRM sync and the customer-segmentation
-- dashboards in Looker. This is the canonical place downstream tools resolve
-- "who is this customer" from customer_id, so it selects that column
-- directly (not just as a join key) -- any rename, drop, or retype of
-- customers.customer_id upstream will break this model outright rather than
-- degrade silently. Treat changes to that column as a breaking change and
-- coordinate with CRM/analytics owners before merging.
create view customer_profile as
with customers as (

    select * from stg_customers

),

orders as (

    select * from stg_orders

),

order_stats as (

    select
        customer_id,
        count(*)            as lifetime_order_count,
        sum(total_amount)   as lifetime_order_value,
        min(order_date)     as first_order_date,
        max(order_date)     as most_recent_order_date

    from orders
    group by customer_id

)

select
    customers.customer_id,
    customers.customer_name,
    customers.customer_email,
    customers.country,
    customers.state,
    customers.city,
    customers.customer_segment,
    customers.signup_date,
    coalesce(order_stats.lifetime_order_count, 0) as lifetime_order_count,
    coalesce(order_stats.lifetime_order_value, 0) as lifetime_order_value,
    order_stats.first_order_date,
    order_stats.most_recent_order_date

from customers
left join order_stats
    on customers.customer_id = order_stats.customer_id;

-- Revenue and order-volume rollup by customer segment and country, used by
-- the quarterly business review deck. Note this model does not project
-- customer_id in its output -- it only uses it as the join key between
-- orders and customers. That makes it easy to overlook as a dependency:
-- a rename would still break the join outright, but a retype or format
-- change on either side's customer_id (e.g. collation, casing, added
-- whitespace) can silently drop matching rows and understate revenue
-- without throwing an error. If customer_id changes upstream, re-validate
-- the join match rate here before trusting the numbers.
create view customer_order_summary as
with orders as (

    select * from stg_orders

),

customers as (

    select * from stg_customers

)

select
    customers.customer_segment,
    customers.country,
    count(distinct orders.order_id)    as order_count,
    sum(orders.total_amount)           as total_revenue,
    avg(orders.total_amount)           as avg_order_value

from orders
inner join customers
    on orders.customer_id = customers.customer_id

group by
    customers.customer_segment,
    customers.country;

-- Per-product stock position and supplier attribution, used by the
-- merchandising team's reorder-planning workflow. Sourced entirely from
-- product, inventory, warehouse, and supplier data -- no customer or order
-- tables involved. Changes to the customer/order side of the warehouse
-- (customer_id, order status codes, etc.) have no impact on this model.
create view product_supplier_inventory as
with products as (

    select * from stg_products

),

inventory as (

    select * from stg_inventory

),

warehouses as (

    select * from stg_warehouses

),

suppliers as (

    select * from stg_suppliers

)

select
    products.product_id,
    products.product_name,
    products.product_category,
    products.brand,
    products.list_price,
    suppliers.supplier_id,
    suppliers.supplier_name,
    suppliers.supplier_status,
    warehouses.warehouse_id,
    warehouses.warehouse_name,
    inventory.quantity_on_hand,
    inventory.quantity_available,
    inventory.reorder_threshold,
    (inventory.quantity_available <= inventory.reorder_threshold) as needs_reorder

from inventory
inner join products
    on inventory.product_id = products.product_id
inner join warehouses
    on inventory.warehouse_id = warehouses.warehouse_id
left join suppliers
    on products.supplier_id = suppliers.supplier_id;

-- Shipment and return performance by carrier and warehouse, used by the
-- logistics team's carrier-scorecard review. Built from order, shipment,
-- and return facts only; customer attributes are out of scope for this
-- model.
create view order_fulfillment_performance as
with orders as (

    select * from stg_orders

),

shipments as (

    select * from stg_shipments

),

returns as (

    select * from stg_returns

),

return_counts as (

    select
        order_id,
        count(*) as return_count
    from returns
    group by order_id

)

select
    orders.order_id,
    orders.order_status,
    orders.shipping_country,
    shipments.carrier,
    shipments.warehouse_id,
    shipments.shipped_date,
    shipments.delivered_date,
    shipments.transit_days,
    shipments.shipment_state,
    coalesce(return_counts.return_count, 0) > 0 as had_return

from orders
inner join shipments
    on orders.order_id = shipments.order_id
left join return_counts
    on orders.order_id = return_counts.order_id;
