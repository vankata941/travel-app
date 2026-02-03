@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Currency Value Help from Rates'
@ObjectModel.resultSet.sizeCategory: #XS -- This creates a dropdown instead of a popup if the list is small

define view entity ZIVI_I_CURRENCY
  as select from zivi_rates
{
      @EndUserText.label: 'Currency Code'
  key currency_source as CurrencyCode
}
group by
  currency_source
