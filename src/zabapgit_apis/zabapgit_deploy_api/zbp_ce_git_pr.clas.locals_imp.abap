CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES gtt_rows TYPE STANDARD TABLE OF zce_git_pr WITH EMPTY KEY.
    CLASS-DATA gt_rows TYPE gtt_rows.
ENDCLASS.

CLASS lcl_buffer IMPLEMENTATION.
ENDCLASS.


CLASS lhc_gitpr DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS create FOR MODIFY
      IMPORTING it_entities FOR CREATE GitPr.

    METHODS read FOR READ
      IMPORTING it_keys FOR READ GitPr RESULT et_result.

    METHODS join_reviewers
      IMPORTING it_reviewers    TYPE string_table
      RETURNING VALUE(rv_text)  TYPE string.

    METHODS join_files
      IMPORTING it_files       TYPE zcl_abapgit_pr_service=>ty_files_tt
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.


CLASS lhc_gitpr IMPLEMENTATION.

  METHOD join_reviewers.
    FIELD-SYMBOLS <lv_reviewer> TYPE string.

    LOOP AT it_reviewers ASSIGNING <lv_reviewer>.
      IF rv_text IS INITIAL.
        rv_text = <lv_reviewer>.
      ELSE.
        rv_text = |{ rv_text },{ <lv_reviewer> }|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD join_files.
    DATA lv_line TYPE string.

    FIELD-SYMBOLS <ls_file> LIKE LINE OF it_files.

    LOOP AT it_files ASSIGNING <ls_file>.
      lv_line = |{ <ls_file>-method } { <ls_file>-obj_type } { <ls_file>-obj_name } | &&
                |{ <ls_file>-path }{ <ls_file>-filename }|.
      IF rv_text IS INITIAL.
        rv_text = lv_line.
      ELSE.
        rv_text = |{ rv_text }{ cl_abap_char_utilities=>newline }{ lv_line }|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD create.

    DATA ls_row      TYPE zce_git_pr.
    DATA lo_service  TYPE REF TO zcl_abapgit_pr_service.
    DATA ls_request  TYPE zcl_abapgit_pr_service=>ty_request.
    DATA ls_preview  TYPE zcl_abapgit_pr_service=>ty_preview.
    DATA ls_result   TYPE zcl_abapgit_pr_service=>ty_result.
    DATA lv_repo_key TYPE zif_abapgit_persistence=>ty_repo-key.
    DATA lx_error    TYPE REF TO zcx_abapgit_exception.

    CLEAR lcl_buffer=>gt_rows.

    LOOP AT it_entities INTO DATA(ls_entity).

      CLEAR ls_row.

      TRY.
          ls_row-request_id = cl_system_uuid=>create_uuid_c32_static( ).
        CATCH cx_uuid_error ##NO_HANDLER.
      ENDTRY.

      " Echo the inputs back, except the token which must never leave the system
      ls_row-devclass     = ls_entity-%data-devclass.
      ls_row-repo_key     = ls_entity-%data-repo_key.
      ls_row-transport    = ls_entity-%data-transport.
      ls_row-preview_only = ls_entity-%data-preview_only.
      ls_row-dry_run      = ls_entity-%data-dry_run.

      CLEAR ls_request.
      ls_request-transport      = ls_entity-%data-transport.
      ls_request-branch_name    = ls_entity-%data-branch_name.
      ls_request-target_branch  = ls_entity-%data-target_branch.
      ls_request-commit_message = ls_entity-%data-commit_message.
      ls_request-commit_body    = ls_entity-%data-commit_body.
      ls_request-pr_title       = ls_entity-%data-pr_title.
      ls_request-pr_body        = ls_entity-%data-pr_body.
      ls_request-git_user       = ls_entity-%data-git_user.
      ls_request-git_token      = ls_entity-%data-git_token.
      ls_request-dry_run        = xsdbool( ls_entity-%data-dry_run = 'X' ).

      lv_repo_key = ls_entity-%data-repo_key.

      TRY.
          lo_service = zcl_abapgit_pr_service=>create( iv_repo_key = lv_repo_key
                                                       iv_package  = ls_entity-%data-devclass ).

          ls_preview = lo_service->preview( ls_request ).

          ls_row-repo_url        = ls_preview-repo_url.
          ls_row-source_branch   = ls_preview-source_branch.
          ls_row-resolved_target = ls_preview-target_branch.
          ls_row-parent_request  = ls_preview-parent_request.
          ls_row-task_request    = ls_preview-task_request.
          ls_row-owner           = ls_preview-owner.
          ls_row-transport_text  = ls_preview-transport_text.
          ls_row-object_count    = ls_preview-object_count.
          ls_row-file_count      = ls_preview-file_count.
          ls_row-reviewers       = join_reviewers( ls_preview-reviewers ).
          ls_row-files           = join_files( ls_preview-files ).

          IF ls_entity-%data-preview_only = 'X'.
            ls_row-success = 'X'.
            ls_row-message = |Preview only: { ls_preview-object_count } object(s) in | &&
                             |{ ls_preview-file_count } file(s). Nothing was changed.|.
          ELSE.
            ls_result = lo_service->stage_and_raise_pr( ls_request ).

            ls_row-success   = ls_result-success.
            ls_row-pr_number = ls_result-pr_number.
            ls_row-pr_url    = ls_result-pr_url.
            ls_row-message   = ls_result-message.
          ENDIF.

        CATCH zcx_abapgit_exception INTO lx_error.
          CLEAR ls_row-success.
          ls_row-message = lx_error->get_text( ).

          INSERT VALUE #( %cid = ls_entity-%cid ) INTO TABLE failed-gitpr.
          INSERT VALUE #( %cid = ls_entity-%cid
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = ls_row-message ) ) INTO TABLE reported-gitpr.
      ENDTRY.

      APPEND ls_row TO lcl_buffer=>gt_rows.

      INSERT VALUE #( %cid       = ls_entity-%cid
                      request_id = ls_row-request_id ) INTO TABLE mapped-gitpr.

    ENDLOOP.

  ENDMETHOD.


  METHOD read.

    DATA ls_result LIKE LINE OF et_result.

    FIELD-SYMBOLS <ls_row> LIKE LINE OF lcl_buffer=>gt_rows.

    LOOP AT it_keys INTO DATA(ls_key).
      READ TABLE lcl_buffer=>gt_rows ASSIGNING <ls_row>
        WITH KEY request_id = ls_key-request_id.
      IF sy-subrc = 0.
        CLEAR ls_result.
        ls_result = CORRESPONDING #( <ls_row> ).
        APPEND ls_result TO et_result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
