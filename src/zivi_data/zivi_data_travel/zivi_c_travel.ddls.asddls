@EndUserText.label: 'Travel Consumption View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true
@Metadata.allowExtensions: true

define root view entity ZIVI_C_TRAVEL
  provider contract transactional_query
  as projection on ZIVI_I_TRAVEL
{
  key TravelUUID,
      
      @Search.defaultSearchElement: true
      TravelID,
      
      @Search.defaultSearchElement: true
      AgencyID,
      
      @Search.defaultSearchElement: true
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZIVI_I_CUSTOMER', element: 'CustomerID' } }]
      CustomerID,
      
      BeginDate,
      EndDate,
      BookingFee,
      TotalPrice,
      CurrencyCode,
      Description,
      OverallStatus,
      CreatedAt,
      LocalLastChangedAt,
      
      /* Associations */
      _Booking : redirected to composition child ZIVI_C_BOOKING,
      _Customer
}
