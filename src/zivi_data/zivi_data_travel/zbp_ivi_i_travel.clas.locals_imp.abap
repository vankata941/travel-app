CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    TYPES: tt_uuid TYPE STANDARD TABLE OF sysuuid_x16 WITH DEFAULT KEY.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Travel RESULT result.

    METHODS validateDates     FOR VALIDATE ON SAVE IMPORTING keys FOR Travel~validateDates.
    METHODS validateCustomer  FOR VALIDATE ON SAVE IMPORTING keys FOR Travel~validateCustomer.

    METHODS acceptTravel FOR MODIFY IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.
    METHODS rejectTravel FOR MODIFY IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Travel RESULT result.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY IMPORTING keys FOR Travel~calculateTotalPrice.
    METHODS calculateTotalPrice_Book FOR DETERMINE ON MODIFY IMPORTING keys FOR Booking~calculateTotalPrice_Book.
    METHODS setTravelID FOR DETERMINE ON MODIFY IMPORTING keys FOR Travel~setTravelID.
    METHODS setInitialStatus FOR DETERMINE ON MODIFY IMPORTING keys FOR Travel~setInitialStatus.
    METHODS setInitialCurrency FOR DETERMINE ON MODIFY IMPORTING keys FOR Travel~setInitialCurrency.

    " Calculate totals for a list of Travel UUIDs
    METHODS recompute_total_price IMPORTING it_travel_uuids TYPE tt_uuid.

ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky    = ls_key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
      FIELDS ( BeginDate EndDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travels).

    LOOP AT lt_travels INTO DATA(ls_travel).

      " Check 1: End Date before Begin Date
      IF ls_travel-EndDate < ls_travel-BeginDate.
        APPEND VALUE #( %tky = ls_travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = ls_travel-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'End Date cannot be before Begin Date!' )
                        %element-BeginDate = if_abap_behv=>mk-on
                        %element-EndDate   = if_abap_behv=>mk-on ) TO reported-travel.

        " Check 2: Begin Date in the past
      ELSEIF ls_travel-BeginDate < cl_abap_context_info=>get_system_date( ).
        APPEND VALUE #( %tky = ls_travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = ls_travel-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Travel cannot start in the past!' )
                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateCustomer.
    " 1. Read relevant travel instances
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
      FIELDS ( CustomerID ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travels).

    DATA lt_customers TYPE SORTED TABLE OF zivi_d_cust_a WITH UNIQUE KEY customer_id.

    " 2. Get all distinct Customer IDs
    lt_customers = CORRESPONDING #( lt_travels DISCARDING DUPLICATES MAPPING customer_id = CustomerID EXCEPT * ).

    IF lt_customers IS NOT INITIAL.
      " 3. Check if they exist in the DB
      SELECT FROM zivi_d_cust_a FIELDS customer_id
        FOR ALL ENTRIES IN @lt_customers
        WHERE customer_id = @lt_customers-customer_id
        INTO TABLE @DATA(lt_db_customers).
    ENDIF.

    " 4. Loop and validate
    LOOP AT lt_travels INTO DATA(ls_travel).
      IF ls_travel-CustomerID IS INITIAL
         OR NOT line_exists( lt_db_customers[ customer_id = ls_travel-CustomerID ] ).

        APPEND VALUE #( %tky = ls_travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = ls_travel-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Customer ID does not exist!' )
                        %element-CustomerID = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD acceptTravel.
    " 1. Update the status to 'A' (Approved)
    MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
      UPDATE FIELDS ( OverallStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'A' ) ).

    " 2. Read the updated data to return it to the UI
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travels).

    " 3. Return the result
    result = VALUE #( FOR travel IN lt_travels ( %tky = travel-%tky %param = travel ) ).
  ENDMETHOD.

  METHOD rejectTravel.
    " 1. Update the status to 'R' (Rejected)
    MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
      UPDATE FIELDS ( OverallStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'R' ) ).

    " 2. Read and Return
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travels).

    result = VALUE #( FOR travel IN lt_travels ( %tky = travel-%tky %param = travel ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    " 1. Read the Status of the selected travels
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
      FIELDS ( OverallStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travels).

    " 2. Decide if buttons should be enabled or disabled
    result = VALUE #( FOR travel IN lt_travels
      ( %tky = travel-%tky

        " Disable Accept if already Accepted (A) or Cancelled (X)
        %action-acceptTravel = COND #( WHEN travel-OverallStatus = 'A' OR travel-OverallStatus = 'X'
                                       THEN if_abap_behv=>fc-o-disabled
                                       ELSE if_abap_behv=>fc-o-enabled )

        " Disable Reject if already Cancelled (X)
        %action-rejectTravel = COND #( WHEN travel-OverallStatus = 'X'
                                       THEN if_abap_behv=>fc-o-disabled
                                       ELSE if_abap_behv=>fc-o-enabled )
      ) ).
  ENDMETHOD.

  METHOD calculateTotalPrice.
    recompute_total_price( VALUE #( FOR key IN keys ( key-TravelUUID ) ) ).
  ENDMETHOD.

  METHOD recompute_total_price.
    IF it_travel_uuids IS INITIAL.
      RETURN.
    ENDIF.

    " 1. Read Travel Headers (Booking Fee & Currency)
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
        FIELDS ( BookingFee CurrencyCode )
        WITH VALUE #( FOR uuid IN it_travel_uuids ( traveluuid = uuid ) )
      RESULT DATA(lt_travels).

    " 2. Read Booking Items (Flight Price & Currency)
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel BY \_Booking
        FIELDS ( FlightPrice CurrencyCode )
        WITH VALUE #( FOR uuid IN it_travel_uuids ( traveluuid = uuid ) )
      RESULT DATA(lt_bookings).

    " 3. Loop and Calculate
    LOOP AT lt_travels ASSIGNING FIELD-SYMBOL(<ls_travel>).
      DATA(lv_total) = <ls_travel>-BookingFee.

      DATA(lv_curr_travel) = to_upper( <ls_travel>-CurrencyCode ).
      CONDENSE lv_curr_travel NO-GAPS.

      LOOP AT lt_bookings INTO DATA(ls_booking) WHERE ParentUUID = <ls_travel>-TravelUUID.

        DATA(lv_curr_book) = to_upper( ls_booking-CurrencyCode ).
        CONDENSE lv_curr_book NO-GAPS.

        IF lv_curr_book = lv_curr_travel.
          lv_total += ls_booking-FlightPrice.

        ELSE.
          SELECT SINGLE exchange_rate
            FROM zivi_rates
            WHERE currency_source = @lv_curr_book
              AND currency_target = @lv_curr_travel
            INTO @DATA(lv_rate).

          IF sy-subrc = 0.
            lv_total += ls_booking-FlightPrice * lv_rate.
          ELSE.
            lv_total += ls_booking-FlightPrice.
          ENDIF.
        ENDIF.

      ENDLOOP.

      " 4. Update the Travel Entity
      MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
        ENTITY Travel
          UPDATE FIELDS ( TotalPrice )
          WITH VALUE #( ( %tky = <ls_travel>-%tky TotalPrice = lv_total ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD calculateTotalPrice_Book.
    " 1. Read the Booking to find the Parent UUID (TravelUUID)
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Booking
      FIELDS ( ParentUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_bookings).

    " 2. Collect unique Travel UUIDs
    DATA(lt_travel_uuids) = VALUE tt_uuid(
      FOR booking IN lt_bookings ( booking-ParentUUID )
    ).

    SORT lt_travel_uuids.
    DELETE ADJACENT DUPLICATES FROM lt_travel_uuids.

    " 3. Trigger the shared calculation logic
    recompute_total_price( lt_travel_uuids ).
  ENDMETHOD.


  METHOD setTravelID.

    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
        FIELDS ( TravelID ) WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    DELETE travels WHERE TravelID IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.

    LOOP AT travels INTO DATA(travel).

      DATA lv_generated_number TYPE n LENGTH 20.

      TRY.
          cl_numberrange_runtime=>number_get(
            EXPORTING
              nr_range_nr = '01'
              object      = 'ZIVI_TRAV'
              quantity    = 1
            IMPORTING
              number      = lv_generated_number ).

          DATA(lv_final_id) = lv_generated_number+14(6).

          MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
            ENTITY Travel
              UPDATE
                FROM VALUE #( ( %tky      = travel-%tky
                                TravelID  = lv_final_id
                                %control-TravelID = if_abap_behv=>mk-on ) ).

        CATCH cx_number_ranges INTO DATA(lx_number_ranges).
          CONTINUE.

      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

  METHOD setInitialStatus.

    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
        FIELDS ( OverallStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    DELETE travels WHERE OverallStatus IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.

    MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
        UPDATE
          FIELDS ( OverallStatus )
          WITH VALUE #( FOR t IN travels
                        ( %tky = t-%tky
                          OverallStatus = 'P' ) ).

  ENDMETHOD.

  METHOD setInitialCurrency.

    " 1. Read the travel currency
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
        FIELDS ( CurrencyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    " 2. Filter: Only process if Currency is empty
    DELETE travels WHERE CurrencyCode IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.

    " 3. Set Currency to 'EUR'
    MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
        UPDATE
          FIELDS ( CurrencyCode )
          WITH VALUE #( FOR t IN travels
                        ( %tky = t-%tky
                          CurrencyCode = 'EUR' ) ).

  ENDMETHOD.

ENDCLASS.

CLASS lhc_Booking DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateFlightDate FOR VALIDATE ON SAVE IMPORTING keys FOR Booking~validateFlightDate.
    METHODS setBookingID FOR DETERMINE ON MODIFY IMPORTING keys FOR Booking~setBookingID.

ENDCLASS.

CLASS lhc_Booking IMPLEMENTATION.

  METHOD validateFlightDate.
    " 1. Read the Booking Data (Flight Date & Parent Key)
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Booking
        FIELDS ( FlightDate ParentUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_bookings).

    " 2. Get unique Parent IDs (to read Travel dates efficiently)
    DATA lt_parent_ids TYPE TABLE OF zivi_i_travel.
    lt_parent_ids = CORRESPONDING #( lt_bookings MAPPING TravelUUID = ParentUUID ).

    " 3. Read the Parent Travel Data (BeginDate, EndDate)
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
        FIELDS ( BeginDate EndDate ) WITH CORRESPONDING #( lt_parent_ids )
      RESULT DATA(lt_travels).

    " 4. Loop through Bookings and Validate
    LOOP AT lt_bookings INTO DATA(ls_booking).

      " Find the parent travel for this booking
      READ TABLE lt_travels INTO DATA(ls_travel) WITH KEY TravelUUID = ls_booking-ParentUUID.

      " Logic: If Flight Date is BEFORE Begin OR AFTER End -> Error
      IF ls_travel-BeginDate IS NOT INITIAL AND ls_travel-EndDate IS NOT INITIAL.

        IF ls_booking-FlightDate < ls_travel-BeginDate OR ls_booking-FlightDate > ls_travel-EndDate.

          " A. Mark as Failed
          APPEND VALUE #( %tky = ls_booking-%tky ) TO failed-booking.

          " B. Add Error Message
          APPEND VALUE #( %tky = ls_booking-%tky
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'Flight Date must be within Travel Begin and End Dates!' )
                          %element-FlightDate = if_abap_behv=>mk-on ) TO reported-booking.
        ENDIF.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD setBookingID.

    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Booking
        FIELDS ( BookingID ) WITH CORRESPONDING #( keys )
      RESULT DATA(bookings).

    DELETE bookings WHERE BookingID IS NOT INITIAL.
    CHECK bookings IS NOT INITIAL.

    LOOP AT bookings INTO DATA(booking).

      DATA lv_generated_number TYPE n LENGTH 20.

      TRY.
          cl_numberrange_runtime=>number_get(
            EXPORTING
              nr_range_nr = '01'
              object      = 'ZIVI_BOOK'
              quantity    = 1
            IMPORTING
              number      = lv_generated_number ).

          DATA(lv_final_id) = lv_generated_number+14(6).

          MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
            ENTITY Booking
              UPDATE
                FROM VALUE #( ( %tky      = booking-%tky
                                BookingID  = lv_final_id
                                %control-BookingID = if_abap_behv=>mk-on ) ).

        CATCH cx_number_ranges INTO DATA(lx_number_ranges).
          CONTINUE.

      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
