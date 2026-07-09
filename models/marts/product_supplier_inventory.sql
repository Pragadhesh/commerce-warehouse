-- Per-product stock position and supplier attribution, used by the
-- merchandising team's reorder-planning workflow. Sourced entirely from
-- product, inventory, warehouse, and supplier data -- no customer or order
-- tables involved. Changes to the customer/order side of the warehouse
-- (customer_id, order status codes, etc.) have no impact on this model.

with products as (

    select * from {{ ref('stg_products') }}

),

inventory as (

    select * from {{ ref('stg_inventory') }}

),

warehouses as (

    select * from {{ ref('stg_warehouses') }}

),

suppliers as (

    select * from {{ ref('stg_suppliers') }}

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
    on products.supplier_id = suppliers.supplier_id
