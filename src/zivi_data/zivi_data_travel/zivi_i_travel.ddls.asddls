@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Travel Interface View'
define root view entity ZIVI_I_TRAVEL
  as select from zivi_d_travel_a as Travel

  /* Associations */
  composition [0..*] of ZIVI_I_BOOKING  as _Booking
  association [0..1] to ZIVI_I_CUSTOMER as _Customer on $projection.CustomerID = _Customer.CustomerID

{
  key travel_uuid            as TravelUUID,
      travel_id              as TravelID,
      agency_id              as AgencyID,
      customer_id            as CustomerID,
      begin_date             as BeginDate,
      end_date               as EndDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      booking_fee            as BookingFee,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_price            as TotalPrice,
      currency_code          as CurrencyCode,
      description            as Description,
      overall_status         as OverallStatus,

      cast( case overall_status
        when 'P' then 'Pending Approval'
        when 'A' then 'Approved'
        when 'R' then 'Rejected'
        else 'Unknown'
      end as abap.char(20) ) as StatusText,

      /* Technical Fields */
      @Semantics.user.createdBy: true
      created_by             as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at             as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by        as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at        as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at  as LocalLastChangedAt,

      /* Public Associations */
      _Booking,
      _Customer
}
