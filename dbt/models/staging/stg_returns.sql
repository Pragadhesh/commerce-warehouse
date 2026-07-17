with source as (

    select * from {{ source('fiction_retail', 'returns') }}

),

renamed as (

    select
        return_id,
        order_id,
        product_id,
        return_date,
        refund_amount,
        return_reason_code,
        processed_by

    from source

)

select * from renamed
