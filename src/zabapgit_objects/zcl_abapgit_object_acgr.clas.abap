CLASS zcl_abapgit_object_acgr DEFINITION PUBLIC INHERITING FROM zcl_abapgit_objects_super FINAL.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_object.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ty_agr_texts TYPE STANDARD TABLE OF agr_texts WITH DEFAULT KEY.
    TYPES ty_agr_1250  TYPE STANDARD TABLE OF agr_1250 WITH DEFAULT KEY.
    TYPES ty_agr_1251  TYPE STANDARD TABLE OF agr_1251 WITH DEFAULT KEY.
    TYPES ty_agr_1252  TYPE STANDARD TABLE OF agr_1252 WITH DEFAULT KEY.
    TYPES ty_agr_hier  TYPE STANDARD TABLE OF agr_hier WITH DEFAULT KEY.
    TYPES ty_agr_hiert TYPE STANDARD TABLE OF agr_hiert WITH DEFAULT KEY.
    TYPES ty_agr_agrs  TYPE STANDARD TABLE OF agr_agrs WITH DEFAULT KEY.
    TYPES ty_agr_flags TYPE STANDARD TABLE OF agr_flags WITH DEFAULT KEY.

    METHODS get_role_name
      RETURNING
        VALUE(rv_agr_name) TYPE agr_name.

    "! Blank out client and administrative fields so the serialized role is system independent
    METHODS clear_volatile_fields
      CHANGING
        !ct_table TYPE ANY TABLE .

ENDCLASS.



CLASS zcl_abapgit_object_acgr IMPLEMENTATION.


  METHOD clear_volatile_fields.

    CONSTANTS lc_fields TYPE string
      VALUE 'MANDT,CREATE_USR,CREATE_DAT,CREATE_TIM,CREATE_TMP,CHANGE_USR,CHANGE_DAT,CHANGE_TIM,CHANGE_TMP'.

    DATA lt_fields TYPE string_table.
    DATA lv_field  LIKE LINE OF lt_fields.

    FIELD-SYMBOLS <ls_row>   TYPE any.
    FIELD-SYMBOLS <lv_value> TYPE any.

    SPLIT lc_fields AT ',' INTO TABLE lt_fields.

    LOOP AT ct_table ASSIGNING <ls_row>.
      LOOP AT lt_fields INTO lv_field.
        ASSIGN COMPONENT lv_field OF STRUCTURE <ls_row> TO <lv_value>.
        IF sy-subrc = 0.
          CLEAR <lv_value>.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_role_name.
    rv_agr_name = ms_item-obj_name.
  ENDMETHOD.


  METHOD zif_abapgit_object~changed_by.

    SELECT SINGLE change_usr FROM agr_define INTO rv_user
      WHERE agr_name = ms_item-obj_name.
    IF sy-subrc <> 0 OR rv_user IS INITIAL.
      SELECT SINGLE create_usr FROM agr_define INTO rv_user
        WHERE agr_name = ms_item-obj_name ##SUBRC_OK.
    ENDIF.

    IF rv_user IS INITIAL.
      rv_user = c_user_unknown.
    ENDIF.

  ENDMETHOD.


  METHOD zif_abapgit_object~delete.
    zcx_abapgit_exception=>raise( |Deleting roles is not supported, use PFCG| ).
  ENDMETHOD.


  METHOD zif_abapgit_object~deserialize.
    zcx_abapgit_exception=>raise( |Role { ms_item-obj_name } cannot be imported, ACGR is serialize only| ).
  ENDMETHOD.


  METHOD zif_abapgit_object~exists.

    DATA lv_agr_name TYPE agr_name.

    SELECT SINGLE agr_name FROM agr_define INTO lv_agr_name
      WHERE agr_name = ms_item-obj_name.
    rv_bool = boolc( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD zif_abapgit_object~get_comparator.
    RETURN.
  ENDMETHOD.


  METHOD zif_abapgit_object~get_deserialize_order.
    RETURN.
  ENDMETHOD.


  METHOD zif_abapgit_object~get_deserialize_steps.
    APPEND zif_abapgit_object=>gc_step_id-late TO rt_steps.
  ENDMETHOD.


  METHOD zif_abapgit_object~get_metadata.
    rs_metadata = get_metadata( ).
  ENDMETHOD.


  METHOD zif_abapgit_object~is_active.
    rv_active = abap_true.
  ENDMETHOD.


  METHOD zif_abapgit_object~is_locked.
    rv_is_locked = abap_false.
  ENDMETHOD.


  METHOD zif_abapgit_object~jump.
    RETURN.
  ENDMETHOD.


  METHOD zif_abapgit_object~map_filename_to_object.
    RETURN.
  ENDMETHOD.


  METHOD zif_abapgit_object~map_object_to_filename.
    RETURN.
  ENDMETHOD.


  METHOD zif_abapgit_object~serialize.

    DATA ls_agr_define TYPE agr_define.
    DATA lt_agr_texts  TYPE ty_agr_texts.
    DATA lt_agr_1250   TYPE ty_agr_1250.
    DATA lt_agr_1251   TYPE ty_agr_1251.
    DATA lt_agr_1252   TYPE ty_agr_1252.
    DATA lt_agr_hier   TYPE ty_agr_hier.
    DATA lt_agr_hiert  TYPE ty_agr_hiert.
    DATA lt_agr_agrs   TYPE ty_agr_agrs.
    DATA lt_agr_flags  TYPE ty_agr_flags.
    DATA lv_agr_name   TYPE agr_name.

    lv_agr_name = get_role_name( ).

    SELECT SINGLE * FROM agr_define INTO ls_agr_define
      WHERE agr_name = lv_agr_name.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CLEAR: ls_agr_define-mandt,
           ls_agr_define-create_usr,
           ls_agr_define-create_dat,
           ls_agr_define-create_tim,
           ls_agr_define-create_tmp,
           ls_agr_define-change_usr,
           ls_agr_define-change_dat,
           ls_agr_define-change_tim,
           ls_agr_define-change_tmp.

    SELECT * FROM agr_texts INTO TABLE lt_agr_texts
      WHERE agr_name = lv_agr_name
      ORDER BY PRIMARY KEY.

    SELECT * FROM agr_1250 INTO TABLE lt_agr_1250
      WHERE agr_name = lv_agr_name
      ORDER BY PRIMARY KEY.

    SELECT * FROM agr_1251 INTO TABLE lt_agr_1251
      WHERE agr_name = lv_agr_name
      ORDER BY PRIMARY KEY.

    SELECT * FROM agr_1252 INTO TABLE lt_agr_1252
      WHERE agr_name = lv_agr_name
      ORDER BY PRIMARY KEY.

    SELECT * FROM agr_hier INTO TABLE lt_agr_hier
      WHERE agr_name = lv_agr_name
      ORDER BY PRIMARY KEY.

    SELECT * FROM agr_hiert INTO TABLE lt_agr_hiert
      WHERE agr_name = lv_agr_name
      ORDER BY PRIMARY KEY.

    SELECT * FROM agr_agrs INTO TABLE lt_agr_agrs
      WHERE agr_name = lv_agr_name
      ORDER BY PRIMARY KEY.

    SELECT * FROM agr_flags INTO TABLE lt_agr_flags
      WHERE agr_name = lv_agr_name
      ORDER BY PRIMARY KEY.

    clear_volatile_fields( CHANGING ct_table = lt_agr_texts ).
    clear_volatile_fields( CHANGING ct_table = lt_agr_1250 ).
    clear_volatile_fields( CHANGING ct_table = lt_agr_1251 ).
    clear_volatile_fields( CHANGING ct_table = lt_agr_1252 ).
    clear_volatile_fields( CHANGING ct_table = lt_agr_hier ).
    clear_volatile_fields( CHANGING ct_table = lt_agr_hiert ).
    clear_volatile_fields( CHANGING ct_table = lt_agr_agrs ).
    clear_volatile_fields( CHANGING ct_table = lt_agr_flags ).

    io_xml->add( iv_name = 'AGR_DEFINE'
                 ig_data = ls_agr_define ).
    io_xml->add( iv_name = 'AGR_TEXTS'
                 ig_data = lt_agr_texts ).
    io_xml->add( iv_name = 'AGR_HIER'
                 ig_data = lt_agr_hier ).
    io_xml->add( iv_name = 'AGR_HIERT'
                 ig_data = lt_agr_hiert ).
    io_xml->add( iv_name = 'AGR_1250'
                 ig_data = lt_agr_1250 ).
    io_xml->add( iv_name = 'AGR_1251'
                 ig_data = lt_agr_1251 ).
    io_xml->add( iv_name = 'AGR_1252'
                 ig_data = lt_agr_1252 ).
    io_xml->add( iv_name = 'AGR_AGRS'
                 ig_data = lt_agr_agrs ).
    io_xml->add( iv_name = 'AGR_FLAGS'
                 ig_data = lt_agr_flags ).

  ENDMETHOD.
ENDCLASS.
