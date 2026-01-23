@EndUserText.label: 'Booking Consumption View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZIVI_C_BOOKING
  as projection on ZIVI_I_BOOKING
{
  key BookingUUID,
      ParentUUID,
      
      @Search.defaultSearchElement: true
      BookingID,
      
      BookingDate,
      CarrierID,
      ConnectionID,
      FlightDate,
      FlightPrice,
      CurrencyCode,
      
      LocalLastChangedAt,
      
      /* Associations */
      _Travel : redirected to parent ZIVI_C_TRAVEL
}
