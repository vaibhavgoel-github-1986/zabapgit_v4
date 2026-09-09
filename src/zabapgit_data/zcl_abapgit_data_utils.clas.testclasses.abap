CLASS ltcl_data_utils_test DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS build_data_filename FOR TESTING RAISING cx_static_check.
    METHODS build_config_filename FOR TESTING RAISING cx_static_check.
    METHODS build_table_itab FOR TESTING RAISING cx_static_check.
    METHODS tabkey_to_where1 FOR TESTING RAISING cx_static_check.
    METHODS tabkey_to_where2 FOR TESTING RAISING cx_static_check.
    METHODS tabkey_to_where3 FOR TESTING RAISING cx_static_check.
    METHODS tabkey_to_where4 FOR TESTING RAISING cx_static_check.
    METHODS with_mandt FOR TESTING RAISING cx_static_check.

ENDCLASS.

CLASS ltcl_data_utils_test IMPLEMENTATION.

  METHOD build_data_filename.

    DATA ls_config TYPE zif_abapgit_data_config=>ty_config.

    ls_config-name = 'T100'.
    ls_config-type = 'TABU'.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_data_utils=>build_data_filename( ls_config )
      exp = 't100.tabu.json' ).

    ls_config-name = '/NSPC/T200'.
    ls_config-type = 'TABU'.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_data_utils=>build_data_filename( ls_config )
      exp = '#nspc#t200.tabu.json' ).

  ENDMETHOD.

  METHOD build_config_filename.

    DATA ls_config TYPE zif_abapgit_data_config=>ty_config.

    ls_config-name = 'T100'.
    ls_config-type = 'TABU'.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_data_utils=>build_config_filename( ls_config )
      exp = 't100.conf.json' ).

    ls_config-name = '/NSPC/T200'.
    ls_config-type = 'TABU'.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_data_utils=>build_config_filename( ls_config )
      exp = '#nspc#t200.conf.json' ).

  ENDMETHOD.

  METHOD build_table_itab.

    DATA lr_data TYPE REF TO data.
    DATA ls_row  TYPE t100.
    FIELD-SYMBOLS <lt_tab> TYPE ANY TABLE.
    FIELD-SYMBOLS <ls_row> TYPE any.

    lr_data = zcl_abapgit_data_utils=>build_table_itab( 'T100' ).
    ASSIGN lr_data->* TO <lt_tab>.

* test that the table works with basic itab operations,
    INSERT ls_row INTO TABLE <lt_tab>.
    cl_abap_unit_assert=>assert_subrc( ).

    READ TABLE <lt_tab> ASSIGNING <ls_row> FROM ls_row.
    cl_abap_unit_assert=>assert_subrc( ).

  ENDMETHOD.

  METHOD tabkey_to_where1.

    DATA lv_where TYPE string.

    lv_where = zcl_abapgit_data_utils=>tabkey_to_where(
      iv_table  = 'T100'
      iv_tabkey = 'EABC55555555555555555001' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_where
      exp = |sprsl = 'E' AND arbgb = 'ABC55555555555555555' AND msgnr = '001'| ).

  ENDMETHOD.

  METHOD tabkey_to_where2.

    DATA lv_where TYPE string.

    lv_where = zcl_abapgit_data_utils=>tabkey_to_where(
      iv_table  = 'T100'
      iv_tabkey = 'ESHORT' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_where
      exp = |sprsl = 'E' AND arbgb = 'SHORT' AND msgnr = ''| ).

  ENDMETHOD.

  METHOD tabkey_to_where3.

    DATA lv_where TYPE string.

    lv_where = zcl_abapgit_data_utils=>tabkey_to_where(
      iv_table  = 'T100'
      iv_tabkey = 'ESHORT               001' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_where
      exp = |sprsl = 'E' AND arbgb = 'SHORT' AND msgnr = '001'| ).

  ENDMETHOD.

  METHOD tabkey_to_where4.

    DATA lv_where TYPE string.

    lv_where = zcl_abapgit_data_utils=>tabkey_to_where(
      iv_table  = 'T100'
      iv_tabkey = 'ESHORT               0' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_where
      exp = |sprsl = 'E' AND arbgb = 'SHORT' AND msgnr = '0'| ).

  ENDMETHOD.

  METHOD with_mandt.

    DATA lv_where TYPE string.

    IF sy-sysid = 'ABC'.
* don't run on open-abap
      RETURN.
    ENDIF.

    lv_where = zcl_abapgit_data_utils=>tabkey_to_where(
      iv_table  = 'USR02'
      iv_tabkey = '100ASDF' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_where
      exp = |bname = 'ASDF'| ).

  ENDMETHOD.

ENDCLASS.
