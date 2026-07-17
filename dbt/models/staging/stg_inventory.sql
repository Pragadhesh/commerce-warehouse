with source as (

    select * from {{ source('fiction_retail', 'inventory') }}

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

select * from renamed
