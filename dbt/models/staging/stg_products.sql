with source as (

    select * from {{ source('fiction_retail', 'products') }}

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

select * from renamed
