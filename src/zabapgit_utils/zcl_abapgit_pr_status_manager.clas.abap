CLASS zcl_abapgit_pr_status_manager DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES: tt_pr_links TYPE TABLE OF zdt_pull_request WITH DEFAULT KEY.

    CONSTANTS:
      BEGIN OF c_pr_status,
        open     TYPE zde_pr_status VALUE 'OPEN',
        draft    TYPE zde_pr_status VALUE 'DRAFT',
        approved TYPE zde_pr_status VALUE 'APPROVED',
        merged   TYPE zde_pr_status VALUE 'MERGED',
        closed   TYPE zde_pr_status VALUE 'CLOSED',
        changes  TYPE zde_pr_status VALUE 'CHANGES',
      END OF c_pr_status.

    CLASS-METHODS create_pr_link
      IMPORTING
        iv_parent_request   TYPE strkorr
        iv_task_request     TYPE trkorr OPTIONAL
        iv_pr_id            TYPE int8
        iv_pr_status        TYPE zde_pr_status DEFAULT c_pr_status-open
        iv_owner            TYPE tr_as4user OPTIONAL
        iv_exception_reason TYPE string OPTIONAL
        iv_log_handle       TYPE balloghndl OPTIONAL
      RAISING
        zcx_abapgit_exception.

    CLASS-METHODS update_pr_status
      IMPORTING
        iv_parent_request TYPE strkorr
        iv_task_request   TYPE trkorr OPTIONAL
        iv_pr_id          TYPE int8
        iv_pr_status      TYPE zde_pr_status
        iv_log_handle     TYPE balloghndl OPTIONAL
      RAISING
        zcx_abapgit_exception.

    CLASS-METHODS get_pr_tr_linkage
      IMPORTING
        iv_parent_request TYPE strkorr
        iv_task_request   TYPE trkorr OPTIONAL
        iv_pr_id          TYPE int8 OPTIONAL
      RETURNING
        VALUE(rt_links)   TYPE tt_pr_links
      RAISING
        zcx_abapgit_exception.

    CLASS-METHODS delete_pr_link
      IMPORTING
        iv_parent_request TYPE strkorr
        iv_task_request   TYPE trkorr OPTIONAL
        iv_pr_id          TYPE int8
      RAISING
        zcx_abapgit_exception.

    CLASS-METHODS sync_with_github
      IMPORTING
        iv_parent_request TYPE strkorr
        iv_repo_url       TYPE string
        iv_task_request   TYPE trkorr OPTIONAL
        iv_log_handle     TYPE balloghndl OPTIONAL
      RAISING
        zcx_abapgit_exception.

    CLASS-METHODS get_github_pr_status
      IMPORTING
        iv_repo_url      TYPE string
        iv_pr_id         TYPE int8
      RETURNING
        VALUE(rv_status) TYPE zde_pr_status
      RAISING
        zcx_abapgit_exception.
  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-METHODS get_transport_status
      IMPORTING
        iv_request          TYPE trkorr
      RETURNING
        VALUE(rv_tr_status) TYPE trstatus.

    CLASS-METHODS write_log
      IMPORTING
        iv_log_handle TYPE balloghndl
        iv_type       TYPE c DEFAULT 'I'
        iv_message    TYPE string
        iv_detail     TYPE string OPTIONAL.

ENDCLASS.



CLASS ZCL_ABAPGIT_PR_STATUS_MANAGER IMPLEMENTATION.


  METHOD create_pr_link.

    DATA: ls_pr_link TYPE zdt_pull_request,
          lv_request TYPE trkorr.

    " Status is tracked against the task when the PR belongs to a task,
    " otherwise against the parent request itself
    lv_request = COND #( WHEN iv_task_request IS NOT INITIAL
                         THEN iv_task_request
                         ELSE iv_parent_request ).

    " Check if link already exists
    SELECT SINGLE parent_request FROM zdt_pull_request
      INTO @DATA(lv_existing)
      WHERE parent_request = @iv_parent_request
        AND task_request   = @iv_task_request.
    IF sy-subrc = 0.
      write_log( iv_log_handle = iv_log_handle
                 iv_type       = 'E'
                 iv_message    = 'PR link already exists'
                 iv_detail     = |Parent: { iv_parent_request }, Task: { iv_task_request }| ).

      zcx_abapgit_exception=>raise(
        |PR link already exists for request { iv_parent_request } task { iv_task_request }| ).
    ENDIF.

    " Create new PR link
    ls_pr_link-parent_request = iv_parent_request.
    ls_pr_link-task_request = iv_task_request.
    ls_pr_link-pr_id = iv_pr_id.
    ls_pr_link-request_status = get_transport_status( lv_request ).
    ls_pr_link-pr_status = iv_pr_status.
    ls_pr_link-owner = iv_owner.

    IF iv_exception_reason IS SUPPLIED.
      ls_pr_link-exception_reason = iv_exception_reason.
    ENDIF.

    ls_pr_link-created_by = sy-uname.
    ls_pr_link-created_on = sy-datum.
    ls_pr_link-created_at = sy-uzeit.
    ls_pr_link-changed_by = sy-uname.
    ls_pr_link-changed_on = sy-datum.
    ls_pr_link-changed_at = sy-uzeit.

    INSERT zdt_pull_request FROM ls_pr_link.
    IF sy-subrc <> 0.
      write_log( iv_log_handle = iv_log_handle
                 iv_type       = 'E'
                 iv_message    = 'Failed to insert PR link'
                 iv_detail     = |Parent: { iv_parent_request }, Task: { iv_task_request }, PR: { iv_pr_id }| ).

      zcx_abapgit_exception=>raise( |Failed to insert entry in DB| ).
    ENDIF.

    COMMIT WORK.

    write_log( iv_log_handle = iv_log_handle
               iv_type       = 'S'
               iv_message    = 'PR link created'
               iv_detail     = |Parent: { iv_parent_request }, Task: { iv_task_request }, | &&
                               |PR: { iv_pr_id }, Owner: { iv_owner }| ).

  ENDMETHOD.


  METHOD update_pr_status.

    DATA: ls_pr_link TYPE zdt_pull_request,
          lv_request TYPE trkorr.

    lv_request = COND #( WHEN iv_task_request IS NOT INITIAL
                         THEN iv_task_request
                         ELSE iv_parent_request ).

    " Read existing record
    SELECT SINGLE * FROM zdt_pull_request
      INTO ls_pr_link
      WHERE parent_request = iv_parent_request
        AND task_request   = iv_task_request
        AND pr_id = iv_pr_id.

    IF sy-subrc <> 0.
      write_log( iv_log_handle = iv_log_handle
                 iv_type       = 'E'
                 iv_message    = 'PR link not found'
                 iv_detail     = |Parent: { iv_parent_request }, Task: { iv_task_request }, PR: { iv_pr_id }| ).

      zcx_abapgit_exception=>raise(
        |PR link not found for request { iv_parent_request } task { iv_task_request } and PR { iv_pr_id }| ).
    ENDIF.

    " Update status and change info
    ls_pr_link-pr_status = iv_pr_status.
    ls_pr_link-request_status = get_transport_status( lv_request ).
    ls_pr_link-changed_by = sy-uname.
    ls_pr_link-changed_on = sy-datum.
    ls_pr_link-changed_at = sy-uzeit.

    UPDATE zdt_pull_request FROM ls_pr_link.
    IF sy-subrc <> 0.
      write_log( iv_log_handle = iv_log_handle
                 iv_type       = 'E'
                 iv_message    = 'Failed to update PR status'
                 iv_detail     = |Parent: { iv_parent_request }, Task: { iv_task_request }, PR: { iv_pr_id }| ).

      zcx_abapgit_exception=>raise( |Failed to update PR status: { sy-subrc }| ).
    ENDIF.

    COMMIT WORK.

    write_log( iv_log_handle = iv_log_handle
               iv_type       = 'S'
               iv_message    = 'PR status updated'
               iv_detail     = |Parent: { iv_parent_request }, Task: { iv_task_request }, | &&
                               |PR: { iv_pr_id }, Status: { iv_pr_status }| ).

  ENDMETHOD.


  METHOD get_pr_tr_linkage.

    DATA: lr_pr_id TYPE RANGE OF int8,
          lr_task  TYPE RANGE OF trkorr.

    IF NOT iv_pr_id IS INITIAL.
      lr_pr_id = VALUE #( ( sign = 'I' option = 'EQ' low = iv_pr_id ) ).
    ENDIF.

    " When no task is supplied every PR under the parent request is returned,
    " which is what the parent-level rollup needs
    IF NOT iv_task_request IS INITIAL.
      lr_task = VALUE #( ( sign = 'I' option = 'EQ' low = iv_task_request ) ).
    ENDIF.

    SELECT *
      FROM zdt_pull_request
      WHERE parent_request = @iv_parent_request
        AND task_request IN @lr_task
        AND pr_id IN @lr_pr_id
          INTO TABLE @rt_links.

  ENDMETHOD.


  METHOD delete_pr_link.

    DELETE FROM zdt_pull_request
      WHERE parent_request = iv_parent_request
        AND task_request   = iv_task_request
        AND pr_id = iv_pr_id.

    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |Failed to delete PR link: { sy-subrc }| ).
    ENDIF.

    COMMIT WORK.

  ENDMETHOD.


  METHOD sync_with_github.

    DATA: lt_links          TYPE tt_pr_links,
          lv_new_status     TYPE zde_pr_status,
          lv_updated_count  TYPE i,
          lv_request        TYPE trkorr,
          lv_tr_status      TYPE trstatus,
          lv_status_updated TYPE abap_bool.

    FIELD-SYMBOLS: <ls_link> TYPE zdt_pull_request.

    " Get PR links for this parent request, optionally narrowed to a single task
    lt_links = get_pr_tr_linkage( iv_parent_request = iv_parent_request
                                  iv_task_request   = iv_task_request ).
    IF lines( lt_links ) = 0.
      " Nothing linked yet is a normal situation and must never block the caller
      write_log( iv_log_handle = iv_log_handle
                 iv_type       = 'W'
                 iv_message    = 'No pull request linked to this request'
                 iv_detail     = |Parent: { iv_parent_request }, Task: { iv_task_request }| ).
      RETURN.
    ENDIF.

    write_log( iv_log_handle = iv_log_handle
               iv_type       = 'I'
               iv_message    = 'Starting GitHub status sync'
               iv_detail     = |Parent: { iv_parent_request }, Links: { lines( lt_links ) }| ).

    " Update status for each linked PR
    LOOP AT lt_links ASSIGNING <ls_link>.
      CLEAR lv_status_updated.

      TRY.
          " Transport status is tracked per task where the PR belongs to a task
          lv_request = COND #( WHEN <ls_link>-task_request IS NOT INITIAL
                               THEN <ls_link>-task_request
                               ELSE <ls_link>-parent_request ).
          lv_tr_status = get_transport_status( lv_request ).

          " Check if transport status has changed and update if needed
          IF <ls_link>-request_status <> lv_tr_status.
            <ls_link>-request_status = lv_tr_status.
            lv_status_updated = abap_true.
          ENDIF.

          " Get detailed PR status from GitHub API using our new method
          lv_new_status = get_github_pr_status(
            iv_repo_url = iv_repo_url
            iv_pr_id    = <ls_link>-pr_id ).

          " Update if PR status changed
          IF <ls_link>-pr_status <> lv_new_status.
            write_log( iv_log_handle = iv_log_handle
                       iv_type       = 'I'
                       iv_message    = |PR #{ <ls_link>-pr_id } status changed|
                       iv_detail     = |{ <ls_link>-pr_status } -> { lv_new_status }, | &&
                                       |Task: { <ls_link>-task_request }| ).

            <ls_link>-pr_status = lv_new_status.
            lv_status_updated = abap_true.
          ENDIF.

          " Update database record if any status changed
          IF lv_status_updated = abap_true.
            <ls_link>-changed_by = sy-uname.
            <ls_link>-changed_on = sy-datum.
            <ls_link>-changed_at = sy-uzeit.

            UPDATE zdt_pull_request FROM <ls_link>.
            IF sy-subrc = 0.
              lv_updated_count = lv_updated_count + 1.
            ELSE.
              write_log( iv_log_handle = iv_log_handle
                         iv_type       = 'W'
                         iv_message    = |Failed to update PR { <ls_link>-pr_id } in database|
                         iv_detail     = |Task: { <ls_link>-task_request }| ).
            ENDIF.
          ENDIF.

        CATCH cx_root INTO DATA(lx_error).
          " A GitHub or network failure must not abort the sync of the remaining links
          write_log( iv_log_handle = iv_log_handle
                     iv_type       = 'W'
                     iv_message    = |Failed to sync PR { <ls_link>-pr_id }|
                     iv_detail     = |Error: { lx_error->get_text( ) }| ).
      ENDTRY.
    ENDLOOP.

    " Commit all changes
    IF lv_updated_count > 0.
      COMMIT WORK.
    ENDIF.

    write_log( iv_log_handle = iv_log_handle
               iv_type       = 'S'
               iv_message    = 'GitHub status sync completed'
               iv_detail     = |{ lv_updated_count } of { lines( lt_links ) } PR link(s) updated| ).

  ENDMETHOD.


  METHOD get_github_pr_status.

    DATA: lv_user       TYPE string,
          lv_repo       TYPE string,
          lv_auth       TYPE string,
          lv_api_key    TYPE string,
          li_http_agent TYPE REF TO zif_abapgit_http_agent,
          li_github_pr  TYPE REF TO zcl_abapgit_pr_enum_github.

    " Initialize return value
    rv_status = c_pr_status-open.

    TRY.
        " Extract user/repo from URL (for GitHub: https://github.com/user/repo.git)
        FIND PCRE 'github\.com[/:]([^/]+)/([^/]+)' IN iv_repo_url
          SUBMATCHES lv_user lv_repo.

        IF sy-subrc <> 0.
          zcx_abapgit_exception=>raise( |Invalid GitHub URL format: { iv_repo_url }| ).
        ENDIF.

        " Clean repository name (remove .git extension if present)
        lv_repo = replace(
          val   = lv_repo
          regex = '\.git$'
          with  = '' ).

        " Get GitHub API key from TVARVC
        SELECT SINGLE low FROM tvarvc
          INTO @lv_api_key
          WHERE name = 'ZGIT_API_KEY'
            AND type = 'P'.

        IF sy-subrc <> 0 OR lv_api_key IS INITIAL.
          zcx_abapgit_exception=>raise( 'GitHub API key not found in TVARVC table (ZGIT_API_KEY)' ).
        ENDIF.

        " Set authentication using API key
        lv_auth = zcl_abapgit_login_manager=>set(
          iv_uri      = iv_repo_url
          iv_username = 'vaibhago_cisco'
          iv_password = lv_api_key ).

        IF lv_auth IS INITIAL.
          zcx_abapgit_exception=>raise( 'Failed to set GitHub authentication' ).
        ENDIF.

        " Create GitHub PR provider with authentication
        li_http_agent = zcl_abapgit_http_agent=>create( ).
        li_github_pr = NEW #(
          iv_user_and_repo = |{ lv_user }/{ lv_repo }|
          ii_http_agent    = li_http_agent ).

        " Get detailed PR status from GitHub API
        rv_status = li_github_pr->get_pr_detailed_status( CONV i( iv_pr_id ) ).

      CATCH zcx_abapgit_exception.
        " Re-raise the exception with additional context
        zcx_abapgit_exception=>raise( |Failed to fetch PR status for PR { iv_pr_id } from { iv_repo_url }| ).
      CATCH cx_root INTO DATA(lx_root).
        " Handle any other exceptions
        zcx_abapgit_exception=>raise( |Unexpected error while fetching PR status: { lx_root->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.


  METHOD get_transport_status.

    SELECT SINGLE trstatus FROM e070
      INTO rv_tr_status
      WHERE trkorr = iv_request.

    IF sy-subrc <> 0.
      rv_tr_status = 'D'. " Default to Development
    ENDIF.

  ENDMETHOD.


  METHOD write_log.

    " Logging must never interfere with the calling business process
    IF iv_log_handle IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        zcl_abapgit_logging_utils=>write_application_log(
            iv_log_handle = iv_log_handle
            iv_log_type   = iv_type
            iv_message    = iv_message
            iv_detail     = iv_detail ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
