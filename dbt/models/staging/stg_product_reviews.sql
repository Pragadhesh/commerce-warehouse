with source as (

    select * from {{ source('fiction_retail', 'product_reviews') }}

),

renamed as (

    select
        review_id,
        product_id,
        customer_name,
        rating,
        review_text,
        review_date,
        verified_purchase,
        helpful_votes

    from source

)

select * from renamed
