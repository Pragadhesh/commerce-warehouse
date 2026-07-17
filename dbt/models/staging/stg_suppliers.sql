with source as (

    select * from {{ source('fiction_retail', 'suppliers') }}

),

renamed as (

    select
        supplier_id,
        name        as supplier_name,
        country     as supplier_country,
        contract_start_date,
        status      as supplier_status

    from source

)

select * from renamed
