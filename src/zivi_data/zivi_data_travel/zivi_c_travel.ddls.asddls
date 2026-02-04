@EndUserText.label: 'Travel Consumption View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true
@Metadata.allowExtensions: true

define root view entity ZIVI_C_TRAVEL
  provider contract transactional_query
  as projection on ZIVI_I_TRAVEL
{
  key     TravelUUID,

          @Search.defaultSearchElement: true
          @Search.fuzzinessThreshold: 0.7
          TravelID,

          AgencyID,

          @Consumption.valueHelpDefinition: [{ entity: { name: 'ZIVI_I_CUSTOMER', element: 'CustomerID' } }]
          CustomerID,
          
          BeginDate,
          EndDate,
          BookingFee,
          TotalPrice,
          CurrencyCode,
          Description,

          @ObjectModel.text.element: ['StatusText']
          @UI.textArrangement: #TEXT_ONLY
          OverallStatus,

          StatusText,

          CreatedAt,
          LocalLastChangedAt,

          /* Associations */
          _Booking : redirected to composition child ZIVI_C_BOOKING,
          _Customer
}
