CLASS zcl_check_nr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_check_nr IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA lv_num TYPE n LENGTH 20.

    out->write( 'Checking Number Range Object ZIVI_TRAV...' ).

    TRY.
        cl_numberrange_runtime=>number_get(
            EXPORTING
              nr_range_nr = '01'
              object      = 'ZIVI_TRAV'
              quantity    = 1
            IMPORTING
              number      = lv_num ).

              DATA(lv_final_id) = lv_num+14(6).

        out->write( |Success! Generated Number: { lv_final_id }| ).

      CATCH cx_number_ranges INTO DATA(lx_error).
        out->write( 'ERROR OCCURRED:' ).
        out->write( lx_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
