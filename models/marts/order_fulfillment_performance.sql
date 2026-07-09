-- Shipment and return performance by carrier and warehouse, used by the
-- logistics team's carrier-scorecard review. Built from order, shipment,
-- and return facts only; customer attributes are out of scope for this
-- model.

with orders as (

    select * from {{ ref('stg_orders') }}

),

shipments as (

    select * from {{ ref('stg_shipments') }}

),

returns as (

    select * from {{ ref('stg_returns') }}

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
    on orders.order_id = return_counts.order_id
