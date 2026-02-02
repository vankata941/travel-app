CLASS zcl_setup_intervals DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_setup_intervals IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA: lt_interval    TYPE cl_numberrange_intervals=>nr_interval,
          ls_interval    LIKE LINE OF lt_interval,
          lv_error       TYPE c LENGTH 1,
          lv_object_name TYPE c LENGTH 10 VALUE 'ZIVI_TRAV'.

    " Define the Interval
    ls_interval-nrrangenr  = '01'.
    ls_interval-fromnumber = '000001'.
    ls_interval-tonumber   = '999999'.
    ls_interval-procind    = 'I'.
    APPEND ls_interval TO lt_interval.

    " Create the Interval
    TRY.
        cl_numberrange_intervals=>create(
          EXPORTING
            interval  = lt_interval
            object    = lv_object_name
          IMPORTING
            error     = lv_error ).

        IF lv_error IS INITIAL.
          out->write( |Success! Interval '01' created for object { lv_object_name }.| ).
        ELSE.
          out->write( |Error: The system returned an error flag.| ).
        ENDIF.

      CATCH cx_nr_object_not_found INTO DATA(lx_not_found).
        out->write( |Error: Object '{ lv_object_name }' not found.| ).
        out->write( lx_not_found->get_text( ) ).

      CATCH cx_number_ranges INTO DATA(lx_general_error).
        out->write( |Error creating interval: { lx_general_error->get_text( ) }| ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
