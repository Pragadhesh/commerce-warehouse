with source as (

    select * from {{ source('fiction_retail', 'warehouses') }}

),

renamed as (

    select
        warehouse_id,
        name        as warehouse_name,
        city,
        state,
        country,
        capacity_units,
        opened_date

    from source

)

select * from renamed
