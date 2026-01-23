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
    " 1. Update the status to 'A' (Accepted)
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
    " 1. Update the status to 'X' (Cancelled)
    MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
      UPDATE FIELDS ( OverallStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'X' ) ).

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

    " 1. Read Booking Fees
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel
        FIELDS ( BookingFee CurrencyCode )
        WITH VALUE #( FOR uuid IN it_travel_uuids ( traveluuid = uuid ) )
      RESULT DATA(lt_travels).

    " 2. Read Related Bookings
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Travel BY \_Booking
        FIELDS ( FlightPrice CurrencyCode )
        WITH VALUE #( FOR uuid IN it_travel_uuids ( traveluuid = uuid ) )
      RESULT DATA(lt_bookings).

    " 3. Calculate Totals
    LOOP AT lt_travels ASSIGNING FIELD-SYMBOL(<ls_travel>).
      DATA(lv_total) = <ls_travel>-BookingFee.

      LOOP AT lt_bookings INTO DATA(ls_booking) WHERE ParentUUID = <ls_travel>-TravelUUID.
        lv_total = lv_total + ls_booking-FlightPrice.
      ENDLOOP.

      " 4. Update Travel
      MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
        ENTITY Travel
          UPDATE FIELDS ( TotalPrice )
          WITH VALUE #( ( %tky = <ls_travel>-%tky TotalPrice = lv_total ) ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_Booking DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateFlightDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~validateFlightDate.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY IMPORTING keys FOR Booking~calculateTotalPrice.

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
    lt_parent_ids = CORRESPONDING #( lt_bookings DISCARDING DUPLICATES MAPPING TravelUUID = ParentUUID ).

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

METHOD calculateTotalPrice.
    " 1. Read the Parent UUIDs for the modified bookings
    READ ENTITIES OF zivi_i_travel IN LOCAL MODE
      ENTITY Booking
        FIELDS ( ParentUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_bookings).

    " 2. Extract unique Parent UUIDs
    DATA lt_parent_uuids TYPE TABLE OF sysuuid_x16.
    lt_parent_uuids = VALUE #( FOR booking IN lt_bookings ( booking-ParentUUID ) ).

    SORT lt_parent_uuids.
    DELETE ADJACENT DUPLICATES FROM lt_parent_uuids.

    IF lt_parent_uuids IS NOT INITIAL.
       " Read Travel & Bookings for these parents
       READ ENTITIES OF zivi_i_travel IN LOCAL MODE
         ENTITY Travel FIELDS ( BookingFee ) WITH VALUE #( FOR uuid IN lt_parent_uuids ( traveluuid = uuid ) )
         RESULT DATA(lt_travels)
         ENTITY Travel BY \_Booking FIELDS ( FlightPrice ) WITH VALUE #( FOR uuid IN lt_parent_uuids ( traveluuid = uuid ) )
         RESULT DATA(lt_all_bookings).

       " Calculate and Update
       LOOP AT lt_travels ASSIGNING FIELD-SYMBOL(<ls_travel>).
         DATA(lv_total) = <ls_travel>-BookingFee.
         LOOP AT lt_all_bookings INTO DATA(ls_booking) WHERE ParentUUID = <ls_travel>-TravelUUID.
           lv_total += ls_booking-FlightPrice.
         ENDLOOP.

         MODIFY ENTITIES OF zivi_i_travel IN LOCAL MODE
           ENTITY Travel UPDATE FIELDS ( TotalPrice )
           WITH VALUE #( ( %tky = <ls_travel>-%tky TotalPrice = lv_total ) ).
       ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
