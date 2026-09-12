FUNCTION z_abapgit_stage_and_pr.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_REPO_KEY) TYPE  STRING OPTIONAL
*"     VALUE(IV_PACKAGE) TYPE  DEVCLASS OPTIONAL
*"     VALUE(IV_TRANSPORT) TYPE  TRKORR
*"     VALUE(IV_BRANCH_NAME) TYPE  STRING OPTIONAL
*"     VALUE(IV_TARGET_BRANCH) TYPE  STRING OPTIONAL
*"     VALUE(IV_COMMIT_MESSAGE) TYPE  STRING OPTIONAL
*"     VALUE(IV_COMMIT_BODY) TYPE  STRING OPTIONAL
*"     VALUE(IV_PR_TITLE) TYPE  STRING OPTIONAL
*"     VALUE(IV_PR_BODY) TYPE  STRING OPTIONAL
*"     VALUE(IV_GIT_USER) TYPE  STRING OPTIONAL
*"     VALUE(IV_GIT_TOKEN) TYPE  STRING OPTIONAL
*"     VALUE(IV_PREVIEW_ONLY) TYPE  XFELD OPTIONAL
*"     VALUE(IV_DRY_RUN) TYPE  XFELD OPTIONAL
*"  EXPORTING
*"     VALUE(EV_SUCCESS) TYPE  XFELD
*"     VALUE(EV_PR_NUMBER) TYPE  I
*"     VALUE(EV_PR_URL) TYPE  STRING
*"     VALUE(EV_PR_REUSED) TYPE  XFELD
*"     VALUE(EV_SOURCE_BRANCH) TYPE  STRING
*"     VALUE(EV_TARGET_BRANCH) TYPE  STRING
*"     VALUE(EV_REPO_URL) TYPE  STRING
*"     VALUE(EV_PARENT_REQUEST) TYPE  STRKORR
*"     VALUE(EV_TASK_REQUEST) TYPE  TRKORR
*"     VALUE(EV_OWNER) TYPE  TR_AS4USER
*"     VALUE(EV_TRANSPORT_TEXT) TYPE  STRING
*"     VALUE(EV_OBJECT_COUNT) TYPE  I
*"     VALUE(EV_FILE_COUNT) TYPE  I
*"     VALUE(EV_REVIEWERS) TYPE  STRING
*"     VALUE(EV_FILES) TYPE  STRING
*"     VALUE(EV_MESSAGE) TYPE  STRING
*"----------------------------------------------------------------------
  DATA lo_service TYPE REF TO zcl_abapgit_pr_service.
  DATA ls_request TYPE zcl_abapgit_pr_service=>ty_request.
  DATA ls_preview TYPE zcl_abapgit_pr_service=>ty_preview.
  DATA ls_result  TYPE zcl_abapgit_pr_service=>ty_result.
  DATA lv_key     TYPE zif_abapgit_persistence=>ty_repo-key.
  DATA lx_error   TYPE REF TO zcx_abapgit_exception.

  FIELD-SYMBOLS <lv_reviewer> TYPE string.
  FIELD-SYMBOLS <ls_file>     LIKE LINE OF ls_preview-files.

  ls_request-transport      = iv_transport.
  ls_request-branch_name    = iv_branch_name.
  ls_request-target_branch  = iv_target_branch.
  ls_request-commit_message = iv_commit_message.
  ls_request-commit_body    = iv_commit_body.
  ls_request-pr_title       = iv_pr_title.
  ls_request-pr_body        = iv_pr_body.
  ls_request-git_user       = iv_git_user.
  ls_request-git_token      = iv_git_token.
  ls_request-dry_run        = iv_dry_run.

  lv_key = iv_repo_key.

  TRY.
      lo_service = zcl_abapgit_pr_service=>create( iv_repo_key = lv_key
                                                   iv_package  = iv_package ).

      ls_preview = lo_service->preview( ls_request ).

      ev_repo_url       = ls_preview-repo_url.
      ev_source_branch  = ls_preview-source_branch.
      ev_target_branch  = ls_preview-target_branch.
      ev_parent_request = ls_preview-parent_request.
      ev_task_request   = ls_preview-task_request.
      ev_owner          = ls_preview-owner.
      ev_transport_text = ls_preview-transport_text.
      ev_object_count   = ls_preview-object_count.
      ev_file_count     = ls_preview-file_count.

      LOOP AT ls_preview-reviewers ASSIGNING <lv_reviewer>.
        IF ev_reviewers IS INITIAL.
          ev_reviewers = <lv_reviewer>.
        ELSE.
          ev_reviewers = |{ ev_reviewers },{ <lv_reviewer> }|.
        ENDIF.
      ENDLOOP.

      LOOP AT ls_preview-files ASSIGNING <ls_file>.
        IF ev_files IS NOT INITIAL.
          ev_files = |{ ev_files }{ cl_abap_char_utilities=>newline }|.
        ENDIF.
        ev_files = |{ ev_files }{ <ls_file>-method } { <ls_file>-obj_type } | &&
                   |{ <ls_file>-obj_name } { <ls_file>-path }{ <ls_file>-filename }|.
      ENDLOOP.

      IF iv_preview_only = abap_true.
        ev_success = abap_true.
        ev_message = |Preview only: { ls_preview-object_count } object(s) in | &&
                     |{ ls_preview-file_count } file(s). Nothing was changed.|.
        RETURN.
      ENDIF.

      ls_result = lo_service->stage_and_raise_pr( ls_request ).

      ev_success   = ls_result-success.
      ev_pr_number = ls_result-pr_number.
      ev_pr_url    = ls_result-pr_url.
      ev_pr_reused = ls_result-pr_reused.
      ev_message   = ls_result-message.

    CATCH zcx_abapgit_exception INTO lx_error.
      " Class based exceptions cannot cross an RFC boundary, so report the failure as data
      CLEAR ev_success.
      ev_message = lx_error->get_text( ).
  ENDTRY.

ENDFUNCTION.
