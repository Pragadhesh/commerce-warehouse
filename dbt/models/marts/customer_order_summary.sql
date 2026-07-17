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
