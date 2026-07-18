with customers as (

    select * from {{ ref('stg_customers') }}

),

orders as (

    select * from {{ ref('stg_orders') }}

),

order_stats as (

    select
        customer_id,
        count(*)            as lifetime_order_count,
        sum(total)         as lifetime_order_value,
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
    on customers.customer_id = order_stats.customer_id