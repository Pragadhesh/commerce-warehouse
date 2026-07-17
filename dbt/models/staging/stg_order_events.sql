with source as (

    select * from {{ source('fiction_retail', 'order_status_events') }}

),

renamed as (

    select
        event_id,
        order_id,
        event_type,
        event_time

    from source

)

select * from renamed
