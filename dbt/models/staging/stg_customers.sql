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
