with reviews as (

    select * from {{ ref('stg_product_reviews') }}

),

products as (

    select * from {{ ref('stg_products') }}

)

select
    products.product_id,
    products.product_name,
    products.product_category,
    count(reviews.review_id)                               as review_count,
    round(avg(reviews.rating), 2)                          as avg_rating,
    sum(case when reviews.rating <= 2 then 1 else 0 end)   as low_rating_count

from products
inner join reviews
    on products.product_id = reviews.product_id

group by
    products.product_id,
    products.product_name,
    products.product_category
