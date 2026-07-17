with source as (

    select * from {{ source('fiction_retail', 'order_items') }}

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

select * from renamed
