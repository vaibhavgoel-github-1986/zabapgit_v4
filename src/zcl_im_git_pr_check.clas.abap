CLASS zcl_im_git_pr_check DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_ex_cts_request_check.

  PROTECTED SECTION.
    DATA mv_log_handle TYPE balloghndl.

    CONSTANTS:
      BEGIN OF c_request_type,
        workbench    TYPE trfunction VALUE 'K',
        tr_of_copies TYPE trfunction VALUE 'T',
        customizing  TYPE trfunction VALUE 'W',
      END OF c_request_type.

    CONSTANTS:
      BEGIN OF c_tr_status,
        development TYPE trstatus VALUE 'D',
        modifiable  TYPE trstatus VALUE 'O',
        released    TYPE trstatus VALUE 'R',
      END OF c_tr_status.

    METHODS get_parent_request
      IMPORTING iv_request       TYPE trkorr
      RETURNING VALUE(rv_parent) TYPE trkorr
      RAISING   zcx_abapgit_exception.

    METHODS get_repo_url
      RETURNING VALUE(rv_repo_url) TYPE string.

    METHODS sync_pr_status
      IMPORTING iv_parent_request TYPE trkorr
                iv_task_request   TYPE trkorr OPTIONAL
                iv_repo_url       TYPE string.

    METHODS report_pr_status
      IMPORTING iv_parent_request TYPE trkorr
                iv_task_request   TYPE trkorr OPTIONAL.

    METHODS update_transport_to_released
      IMPORTING iv_parent_request TYPE trkorr
                iv_task_request   TYPE trkorr OPTIONAL.

    METHODS write_log
      IMPORTING iv_type    TYPE c DEFAULT 'I'
                iv_message TYPE string
                iv_detail  TYPE string OPTIONAL.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_IM_GIT_PR_CHECK IMPLEMENTATION.


  METHOD if_ex_cts_request_check~check_before_release.
    DATA lv_repo_url       TYPE string.
    DATA lv_parent_request TYPE trkorr.
    DATA lv_task_request   TYPE trkorr.

    TRY.
        " This check is only for Workbench Transports
        IF type = c_request_type-tr_of_copies OR
           type = c_request_type-customizing.
          RETURN.
        ENDIF.

        " Runs for parent requests and for tasks. Developers raise one PR per task,
        " so both levels need their status kept in sync.
        lv_parent_request = get_parent_request( request ).
        IF lv_parent_request <> request.
          lv_task_request = request.
        ENDIF.

        mv_log_handle = zcl_abapgit_logging_utils=>create_application_log( iv_extnumber = CONV #( request )
                                                                           iv_object    = 'ZABAPGIT'
                                                                           iv_subobject = 'TR_CHECK' ).

        write_log( iv_type    = 'I'
                   iv_message = 'PR check started'
                   iv_detail  = |Request: { request }, Parent: { lv_parent_request }, | &&
                                |Task: { lv_task_request }, Type: { type }| ).

        " Check for Exception
        SELECT SINGLE * FROM zdt_pull_request
          INTO @DATA(ls_pull_request)
         WHERE parent_request = @lv_parent_request
           AND task_request   = @lv_task_request.
        IF sy-subrc IS INITIAL AND ls_pull_request-pr_status = 'EXCEPTION'.
          write_log( iv_type    = 'I'
                     iv_message = 'Request was granted an exception, no PR sync performed'
                     iv_detail  = |Request: { request }, Reason: { ls_pull_request-exception_reason }| ).
          RETURN.
        ENDIF.

        lv_repo_url = get_repo_url( ).
        IF lv_repo_url IS INITIAL.
          " Missing configuration stops the sync, never the release
          write_log( iv_type    = 'W'
                     iv_message = 'Repository URL not configured, skipping GitHub sync'
                     iv_detail  = 'ZGIT_REPO_URL entry missing in TVARVC table' ).
        ELSE.
          sync_pr_status( iv_parent_request = lv_parent_request
                          iv_task_request   = lv_task_request
                          iv_repo_url       = lv_repo_url ).
        ENDIF.

        " Informational only - an unmerged PR does not prevent the release
        report_pr_status( iv_parent_request = lv_parent_request
                          iv_task_request   = lv_task_request ).

        update_transport_to_released( iv_parent_request = lv_parent_request
                                      iv_task_request   = lv_task_request ).

        write_log( iv_type    = 'S'
                   iv_message = 'PR check completed'
                   iv_detail  = |Request { request } processed| ).

      CATCH cx_root INTO DATA(lx_root).
        " PR bookkeeping must never block a transport release
        write_log( iv_type    = 'E'
                   iv_message = 'Unexpected error during PR check'
                   iv_detail  = |Error: { lx_root->get_text( ) }| ).

        MESSAGE |PR check skipped: { lx_root->get_text( ) }| TYPE 'S' DISPLAY LIKE 'W'.
    ENDTRY.
  ENDMETHOD.


  METHOD get_repo_url.
    " Get repository URL from TVARVC table
    SELECT SINGLE low FROM tvarvc
      INTO @rv_repo_url
      WHERE name = 'ZGIT_REPO_URL'.
    IF sy-subrc <> 0.
      CLEAR rv_repo_url.
    ENDIF.
  ENDMETHOD.


  METHOD sync_pr_status.
    " Keeps the SAP side up to date with GitHub. Failures are logged and swallowed
    " so that neither a network problem nor a missing PR can block the release.
    TRY.
        zcl_abapgit_pr_status_manager=>sync_with_github(
            iv_parent_request = CONV #( iv_parent_request )
            iv_task_request   = iv_task_request
            iv_repo_url       = iv_repo_url
            iv_log_handle     = mv_log_handle ).

      CATCH cx_root INTO DATA(lx_root).
        write_log( iv_type    = 'W'
                   iv_message = 'GitHub sync failed, release continues'
                   iv_detail  = |Error: { lx_root->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD report_pr_status.
    DATA lt_pr_links TYPE zcl_abapgit_pr_status_manager=>tt_pr_links.
    DATA lv_open     TYPE i.
    DATA lv_detail   TYPE string.

    TRY.
        lt_pr_links = zcl_abapgit_pr_status_manager=>get_pr_tr_linkage(
                          iv_parent_request = CONV #( iv_parent_request )
                          iv_task_request   = iv_task_request ).

        LOOP AT lt_pr_links INTO DATA(ls_pr_link).
          IF ls_pr_link-pr_status = zcl_abapgit_pr_status_manager=>c_pr_status-open
             OR ls_pr_link-pr_status = zcl_abapgit_pr_status_manager=>c_pr_status-draft
             OR ls_pr_link-pr_status = zcl_abapgit_pr_status_manager=>c_pr_status-changes.

            lv_open = lv_open + 1.
            lv_detail = |{ lv_detail }PR #{ ls_pr_link-pr_id } ({ ls_pr_link-pr_status }) | &&
                        |task { ls_pr_link-task_request } owner { ls_pr_link-owner }; |.
          ENDIF.
        ENDLOOP.

        IF lv_open > 0.
          write_log( iv_type    = 'W'
                     iv_message = |{ lv_open } pull request(s) not yet merged|
                     iv_detail  = lv_detail ).

          MESSAGE |{ lv_open } linked pull request(s) are not merged yet| TYPE 'S' DISPLAY LIKE 'W'.
        ELSE.
          write_log( iv_type    = 'S'
                     iv_message = 'All linked pull requests are merged or closed'
                     iv_detail  = |Links checked: { lines( lt_pr_links ) }| ).
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        write_log( iv_type    = 'W'
                   iv_message = 'Could not evaluate PR status'
                   iv_detail  = |Error: { lx_root->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD update_transport_to_released.
    DATA lr_task TYPE RANGE OF trkorr.

    " A task release only stamps its own row, a parent release stamps every row below it
    IF iv_task_request IS NOT INITIAL.
      lr_task = VALUE #( ( sign = 'I' option = 'EQ' low = iv_task_request ) ).
    ENDIF.

    UPDATE zdt_pull_request
      SET request_status = @c_tr_status-released,
          changed_by     = @sy-uname,
          changed_on     = @sy-datum,
          changed_at     = @sy-uzeit
      WHERE parent_request = @iv_parent_request
        AND task_request  IN @lr_task.

    IF sy-subrc = 0.
      COMMIT WORK.

      write_log( iv_type    = 'S'
                 iv_message = 'Transport status updated to Released'
                 iv_detail  = |{ sy-dbcnt } PR record(s) updated in ZDT_PULL_REQUEST| ).
    ELSE.
      write_log( iv_type    = 'W'
                 iv_message = 'No PR records found to update'
                 iv_detail  = |Parent: { iv_parent_request }, Task: { iv_task_request }| ).
    ENDIF.
  ENDMETHOD.


  METHOD write_log.
    " Logging must never interfere with the release itself
    IF mv_log_handle IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        zcl_abapgit_logging_utils=>write_application_log( iv_log_handle = mv_log_handle
                                                          iv_log_type   = iv_type
                                                          iv_message    = iv_message
                                                          iv_detail     = iv_detail ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.


  METHOD if_ex_cts_request_check~check_before_add_objects.
  ENDMETHOD.


  METHOD if_ex_cts_request_check~check_before_changing_owner.
  ENDMETHOD.


  METHOD if_ex_cts_request_check~check_before_creation.
  ENDMETHOD.


  METHOD if_ex_cts_request_check~check_before_release_slin.
  ENDMETHOD.


  METHOD get_parent_request.
    DATA lv_strkorr TYPE trkorr.

    SELECT SINGLE strkorr
      FROM e070
      INTO @lv_strkorr
      WHERE trkorr = @iv_request.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |Transport request { iv_request } not found| ).
    ENDIF.

    " A task carries its parent in STRKORR, a request is its own parent
    IF lv_strkorr IS INITIAL.
      rv_parent = iv_request.
    ELSE.
      rv_parent = lv_strkorr.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
