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
ENDCLASS.


CLASS lhc_gitpr IMPLEMENTATION.

  METHOD create.

    DATA ls_row TYPE zce_git_pr.

    DATA lv_success        TYPE xfeld.
    DATA lv_pr_number      TYPE i.
    DATA lv_pr_url         TYPE string.
    DATA lv_pr_reused      TYPE xfeld.
    DATA lv_source_branch  TYPE string.
    DATA lv_target_branch  TYPE string.
    DATA lv_repo_url       TYPE string.
    DATA lv_parent_request TYPE strkorr.
    DATA lv_task_request   TYPE trkorr.
    DATA lv_owner          TYPE tr_as4user.
    DATA lv_transport_text TYPE string.
    DATA lv_object_count   TYPE i.
    DATA lv_file_count     TYPE i.
    DATA lv_reviewers      TYPE string.
    DATA lv_files          TYPE string.
    DATA lv_message        TYPE string.
    DATA lv_rfc_message    TYPE c LENGTH 200.

    CLEAR lcl_buffer=>gt_rows.

    LOOP AT it_entities INTO DATA(ls_entity).

      CLEAR ls_row.
      CLEAR: lv_success, lv_pr_number, lv_pr_url, lv_pr_reused, lv_source_branch,
             lv_target_branch, lv_repo_url, lv_parent_request, lv_task_request,
             lv_owner, lv_transport_text, lv_object_count, lv_file_count,
             lv_reviewers, lv_files, lv_message, lv_rfc_message.

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

      " abapGit commits its own work and RAP forbids COMMIT WORK inside a handler,
      " so the operation runs in its own LUW behind an RFC hop to the same system
      CALL FUNCTION 'Z_ABAPGIT_STAGE_AND_PR'
        DESTINATION 'NONE'
        EXPORTING
          iv_repo_key           = CONV string( ls_entity-%data-repo_key )
          iv_package            = ls_entity-%data-devclass
          iv_transport          = ls_entity-%data-transport
          iv_branch_name        = CONV string( ls_entity-%data-branch_name )
          iv_target_branch      = CONV string( ls_entity-%data-target_branch )
          iv_commit_message     = CONV string( ls_entity-%data-commit_message )
          iv_commit_body        = CONV string( ls_entity-%data-commit_body )
          iv_pr_title           = CONV string( ls_entity-%data-pr_title )
          iv_pr_body            = CONV string( ls_entity-%data-pr_body )
          iv_git_user           = CONV string( ls_entity-%data-git_user )
          iv_git_token          = CONV string( ls_entity-%data-git_token )
          iv_preview_only       = ls_entity-%data-preview_only
          iv_dry_run            = ls_entity-%data-dry_run
        IMPORTING
          ev_success            = lv_success
          ev_pr_number          = lv_pr_number
          ev_pr_url             = lv_pr_url
          ev_pr_reused          = lv_pr_reused
          ev_source_branch      = lv_source_branch
          ev_target_branch      = lv_target_branch
          ev_repo_url           = lv_repo_url
          ev_parent_request     = lv_parent_request
          ev_task_request       = lv_task_request
          ev_owner              = lv_owner
          ev_transport_text     = lv_transport_text
          ev_object_count       = lv_object_count
          ev_file_count         = lv_file_count
          ev_reviewers          = lv_reviewers
          ev_files              = lv_files
          ev_message            = lv_message
        EXCEPTIONS
          system_failure        = 1 MESSAGE lv_rfc_message
          communication_failure = 2 MESSAGE lv_rfc_message
          OTHERS                = 3.

      IF sy-subrc <> 0.
        CLEAR lv_success.
        IF lv_rfc_message IS INITIAL.
          lv_message = |Remote call failed with return code { sy-subrc }|.
        ELSE.
          lv_message = lv_rfc_message.
        ENDIF.
      ENDIF.

      ls_row-success         = lv_success.
      ls_row-pr_number       = lv_pr_number.
      ls_row-pr_url          = lv_pr_url.
      ls_row-source_branch   = lv_source_branch.
      ls_row-resolved_target = lv_target_branch.
      ls_row-repo_url        = lv_repo_url.
      ls_row-parent_request  = lv_parent_request.
      ls_row-task_request    = lv_task_request.
      ls_row-owner           = lv_owner.
      ls_row-transport_text  = lv_transport_text.
      ls_row-object_count    = lv_object_count.
      ls_row-file_count      = lv_file_count.
      ls_row-reviewers       = lv_reviewers.
      ls_row-files           = lv_files.
      ls_row-message         = lv_message.

      IF lv_success IS INITIAL.
        INSERT VALUE #( %cid = ls_entity-%cid ) INTO TABLE failed-gitpr.
        INSERT VALUE #( %cid = ls_entity-%cid
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = lv_message ) ) INTO TABLE reported-gitpr.
      ENDIF.

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
