CLASS zcl_ivi_generate_demo_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_ivi_generate_demo_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " --- 1. Generate CUSTOMER Data ---
    DATA: lt_customers TYPE TABLE OF zivi_d_cust_a.

    lt_customers = VALUE #(
      ( customer_id = '000001' first_name = 'Alice' last_name = 'Wonder' email_address = 'alice@test.com' phone_number = '+1 555-0101' country_code = 'US' )
      ( customer_id = '000002' first_name = 'Bob'   last_name = 'Builder' email_address = 'bob@test.com'   phone_number = '+49 123-4567' country_code = 'DE' )
      ( customer_id = '000003' first_name = 'Carol' last_name = 'Danvers' email_address = 'carol@test.com' phone_number = '+44 20 7946'  country_code = 'UK' )
    ).

    " --- 2. Generate TRAVEL Data ---
    DATA: lt_travels TYPE TABLE OF zivi_d_travel_a.
    DATA: lt_bookings TYPE TABLE OF zivi_d_booking_a.

    " Generate random UUIDs for the keys
    DATA(lv_travel_uuid_1) = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(lv_travel_uuid_2) = cl_system_uuid=>create_uuid_x16_static( ).

    " Get current timestamp for admin fields
    GET TIME STAMP FIELD DATA(lv_ts).

    lt_travels = VALUE #(
      ( travel_uuid = lv_travel_uuid_1 travel_id = '00000001' agency_id = '070001' customer_id = '000001'
        begin_date = '20240101' end_date = '20240105' booking_fee = '10.00' total_price = '110.00' currency_code = 'EUR'
        description = 'Business Trip to Walldorf' overall_status = 'O'
        created_by = 'GENERATOR' created_at = lv_ts local_last_changed_at = lv_ts )

      ( travel_uuid = lv_travel_uuid_2 travel_id = '00000002' agency_id = '070005' customer_id = '000002'
        begin_date = '20240510' end_date = '20240515' booking_fee = '20.00' total_price = '520.00' currency_code = 'USD'
        description = 'Conference in New York' overall_status = 'A'
        created_by = 'GENERATOR' created_at = lv_ts local_last_changed_at = lv_ts )
    ).

    " --- 3. Generate BOOKING Data (Linked to Travel) ---
    lt_bookings = VALUE #(
      " Booking for Travel 1
      ( booking_uuid = cl_system_uuid=>create_uuid_x16_static( ) parent_uuid = lv_travel_uuid_1 booking_id = '1'
        booking_date = '20231201' carrier_id = 'LH' connection_id = '0400' flight_date = '20240101' flight_price = '100.00' currency_code = 'EUR'
        local_last_changed_at = lv_ts )

      " Booking for Travel 2
      ( booking_uuid = cl_system_uuid=>create_uuid_x16_static( ) parent_uuid = lv_travel_uuid_2 booking_id = '2'
        booking_date = '20240401' carrier_id = 'AA' connection_id = '0017' flight_date = '20240510' flight_price = '500.00' currency_code = 'USD'
        local_last_changed_at = lv_ts )
    ).

    " --- 4. CLEAR & INSERT ---
    DELETE FROM zivi_d_travel_a.
    DELETE FROM zivi_d_booking_a.
    DELETE FROM zivi_d_cust_a.

    INSERT zivi_d_cust_a FROM TABLE @lt_customers.
    INSERT zivi_d_travel_a FROM TABLE @lt_travels.
    INSERT zivi_d_booking_a FROM TABLE @lt_bookings.

    out->write( 'Database refreshed! Created 3 Customers, 2 Travels, 2 Bookings.' ).

  ENDMETHOD.
ENDCLASS.
