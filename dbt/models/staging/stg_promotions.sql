with source as (

    select * from {{ source('fiction_retail', 'promotions') }}

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

select * from renamed
