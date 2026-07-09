-- Revenue and order-volume rollup by customer segment and country, used by
-- the quarterly business review deck. Note this model does not project
-- customer_id in its output -- it only uses it as the join key between
-- orders and customers. That makes it easy to overlook as a dependency:
-- a rename would still break the join outright, but a retype or format
-- change on either side's customer_id (e.g. collation, casing, added
-- whitespace) can silently drop matching rows and understate revenue
-- without throwing an error. If customer_id changes upstream, re-validate
-- the join match rate here before trusting the numbers.

with orders as (

    select * from {{ ref('stg_orders') }}

),

customers as (

    select * from {{ ref('stg_customers') }}

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
    customers.country
