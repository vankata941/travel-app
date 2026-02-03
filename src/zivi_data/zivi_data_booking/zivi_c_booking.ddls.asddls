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
      
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZIVI_I_CURRENCY', element: 'CurrencyCode' } }]
      CurrencyCode,
      
      LocalLastChangedAt,
      
      /* Associations */
      _Travel : redirected to parent ZIVI_C_TRAVEL
}
