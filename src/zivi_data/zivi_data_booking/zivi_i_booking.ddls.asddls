@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Booking Interface View'
define view entity ZIVI_I_BOOKING
  as select from zivi_d_booking_a as Booking
  association to parent ZIVI_I_TRAVEL as _Travel on $projection.ParentUUID = _Travel.TravelUUID
{
  key booking_uuid          as BookingUUID,
      parent_uuid           as ParentUUID,
      booking_id            as BookingID,
      booking_date          as BookingDate,
      carrier_id            as CarrierID,
      connection_id         as ConnectionID,
      flight_date           as FlightDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      flight_price          as FlightPrice,
      currency_code         as CurrencyCode,
      
      /*Technical Fields*/
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      
      /* Public Associations */
      _Travel
}
