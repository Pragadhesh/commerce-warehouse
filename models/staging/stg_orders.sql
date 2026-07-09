with source as (

    select * from {{ source('fiction_retail', 'orders') }}

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

select * from renamed
