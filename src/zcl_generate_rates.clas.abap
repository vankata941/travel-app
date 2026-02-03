CLASS zcl_generate_rates DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_generate_rates IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA: lt_rates TYPE STANDARD TABLE OF zivi_rates.

    " Clear the table first so we don't get duplicate key errors
    DELETE FROM zivi_rates.

    lt_rates = VALUE #(
      " --- EUR Base Rates ---
      ( client = sy-mandt currency_source = 'USD' currency_target = 'EUR' exchange_rate = '0.85' )
      ( client = sy-mandt currency_source = 'EUR' currency_target = 'USD' exchange_rate = '1.18' )

      ( client = sy-mandt currency_source = 'GBP' currency_target = 'EUR' exchange_rate = '1.16' )
      ( client = sy-mandt currency_source = 'EUR' currency_target = 'GBP' exchange_rate = '0.86' )

      ( client = sy-mandt currency_source = 'JPY' currency_target = 'EUR' exchange_rate = '0.0075' )
      ( client = sy-mandt currency_source = 'EUR' currency_target = 'JPY' exchange_rate = '133.00' )

      ( client = sy-mandt currency_source = 'CHF' currency_target = 'EUR' exchange_rate = '0.96' )
      ( client = sy-mandt currency_source = 'EUR' currency_target = 'CHF' exchange_rate = '1.04' )

      " --- USD Base Rates ---
      ( client = sy-mandt currency_source = 'GBP' currency_target = 'USD' exchange_rate = '1.38' )
      ( client = sy-mandt currency_source = 'USD' currency_target = 'GBP' exchange_rate = '0.72' )

      ( client = sy-mandt currency_source = 'JPY' currency_target = 'USD' exchange_rate = '0.009' )
      ( client = sy-mandt currency_source = 'USD' currency_target = 'JPY' exchange_rate = '110.0' )

      ( client = sy-mandt currency_source = 'CAD' currency_target = 'USD' exchange_rate = '0.79' )
      ( client = sy-mandt currency_source = 'USD' currency_target = 'CAD' exchange_rate = '1.26' )

      " --- AUD Base Rates ---
      ( client = sy-mandt currency_source = 'AUD' currency_target = 'EUR' exchange_rate = '0.60' )
      ( client = sy-mandt currency_source = 'EUR' currency_target = 'AUD' exchange_rate = '1.66' )

      ( client = sy-mandt currency_source = 'AUD' currency_target = 'USD' exchange_rate = '0.73' )
      ( client = sy-mandt currency_source = 'USD' currency_target = 'AUD' exchange_rate = '1.37' )
    ).

    MODIFY zivi_rates FROM TABLE @lt_rates.

    out->write( |Success! Injected { lines( lt_rates ) } exchange rates into ZIVI_RATES.| ).
  ENDMETHOD.
ENDCLASS.
