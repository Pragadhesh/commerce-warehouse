-- Light cleanup of the raw customers extract: stable column names and
-- typing only, no business logic. Downstream marts should build on this
-- model rather than querying raw.customers directly.

with source as (

    select * from {{ source('fiction_retail', 'customers') }}

),

renamed as (

    select
        customer_id,
        name                as customer_name,
        email               as customer_email,
        phone               as customer_phone,
        signup_date,
        country,
        state,
        city,
        customer_segment

    from source

)

select * from renamed
