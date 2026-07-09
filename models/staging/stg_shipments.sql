with source as (

    select * from {{ source('fiction_retail', 'shipments') }}

),

renamed as (

    select
        shipment_id,
        order_id,
        warehouse_id,
        carrier,
        tracking_number,
        shipped_date,
        delivered_date,
        shipment_state,
        case
            when delivered_date is not null
                then delivered_date - shipped_date
        end as transit_days

    from source

)

select * from renamed
