@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Customer Interface View'
define view entity ZIVI_I_CUSTOMER
  as select from zivi_d_cust_a
{
  key customer_id       as CustomerID,
      first_name        as FirstName,
      last_name         as LastName,
      email_address     as EmailAddress,
      phone_number      as PhoneNumber,
      country_code      as CountryCode,
      
      /*Techical Fields*/
      local_last_changed_at as LocalLastChangedAt
}
