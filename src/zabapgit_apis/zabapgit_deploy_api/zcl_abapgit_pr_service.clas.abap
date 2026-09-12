CLASS zcl_abapgit_pr_service DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_file,
        obj_type TYPE trobjtype,
        obj_name TYPE sobj_name,
        path     TYPE string,
        filename TYPE string,
        method   TYPE zif_abapgit_definitions=>ty_method,
      END OF ty_file .
    TYPES:
      ty_files_tt TYPE STANDARD TABLE OF ty_file WITH DEFAULT KEY .

    TYPES:
      BEGIN OF ty_request,
        transport      TYPE trkorr,
        branch_name    TYPE string,
        target_branch  TYPE string,
        commit_message TYPE string,
        commit_body    TYPE string,
        pr_title       TYPE string,
        pr_body        TYPE string,
        reviewers      TYPE string_table,
        git_user       TYPE string,
        " Caller's own GitHub token. Never stored, never logged.
        git_token      TYPE string,
        dry_run        TYPE abap_bool,
      END OF ty_request .

    TYPES:
      BEGIN OF ty_preview,
        repo_key       TYPE zif_abapgit_persistence=>ty_repo-key,
        repo_url       TYPE string,
        package        TYPE devclass,
        transport      TYPE trkorr,
        parent_request TYPE strkorr,
        task_request   TYPE trkorr,
        owner          TYPE tr_as4user,
        transport_text TYPE string,
        source_branch  TYPE string,
        target_branch  TYPE string,
        object_count   TYPE i,
        file_count     TYPE i,
        files          TYPE ty_files_tt,
        reviewers      TYPE string_table,
        " Set when a previous run already pushed this transport
        branch_exists  TYPE abap_bool,
        open_pr_number TYPE int8,
        open_pr_status TYPE zde_pr_status,
      END OF ty_preview .

    TYPES:
      BEGIN OF ty_result,
        success       TYPE abap_bool,
        transport     TYPE trkorr,
        source_branch TYPE string,
        target_branch TYPE string,
        pr_number     TYPE i,
        pr_url        TYPE string,
        " X when an already open pull request was pushed to instead of raising a new one
        pr_reused     TYPE abap_bool,
        object_count  TYPE i,
        file_count    TYPE i,
        reviewers     TYPE string_table,
        log_handle    TYPE balloghndl,
        message       TYPE string,
      END OF ty_result .

    " Values that are hardcoded inside ZCL_ABAPGIT_GUI_PAGE_COMMIT
    CONSTANTS c_tvarvc_reviewers TYPE rvari_vnam VALUE 'Z_CODE_REVIEWERS' ##NO_TEXT.
    CONSTANTS c_default_reviewer TYPE string VALUE 'sekanaga_cisco' ##NO_TEXT.
    CONSTANTS c_github_user_suffix TYPE string VALUE '_cisco' ##NO_TEXT.
    CONSTANTS c_branch_prefix TYPE string VALUE 'feature/' ##NO_TEXT.

    CLASS-METHODS create
      IMPORTING
        !iv_repo_key      TYPE zif_abapgit_persistence=>ty_repo-key OPTIONAL
        !iv_package       TYPE devclass OPTIONAL
      RETURNING
        VALUE(ro_service) TYPE REF TO zcl_abapgit_pr_service
      RAISING
        zcx_abapgit_exception .

    METHODS constructor
      IMPORTING
        !ii_repo TYPE REF TO zif_abapgit_repo
      RAISING
        zcx_abapgit_exception .

    METHODS preview
      IMPORTING
        !is_request       TYPE ty_request
      RETURNING
        VALUE(rs_preview) TYPE ty_preview
      RAISING
        zcx_abapgit_exception .

    METHODS stage_and_raise_pr
      IMPORTING
        !is_request      TYPE ty_request
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_abapgit_exception .

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA mi_repo TYPE REF TO zif_abapgit_repo .
    DATA mi_repo_online TYPE REF TO zif_abapgit_repo_online .
    DATA mv_log_handle TYPE balloghndl .
    DATA mv_user_and_repo TYPE string .

    METHODS assert_transport_usable
      IMPORTING
        !iv_transport TYPE trkorr
      RAISING
        zcx_abapgit_exception .

    METHODS get_parent_request
      IMPORTING
        !iv_request      TYPE trkorr
      RETURNING
        VALUE(rv_parent) TYPE strkorr .

    METHODS get_request_owner
      IMPORTING
        !iv_request     TYPE trkorr
      RETURNING
        VALUE(rv_owner) TYPE tr_as4user .

    METHODS get_transport_description
      IMPORTING
        !iv_transport         TYPE trkorr
      RETURNING
        VALUE(rv_description) TYPE string .

    METHODS build_object_filter
      IMPORTING
        !iv_transport    TYPE trkorr
      RETURNING
        VALUE(ri_filter) TYPE REF TO zif_abapgit_object_filter
      RAISING
        zcx_abapgit_exception .

    METHODS collect_stage_files
      IMPORTING
        !iv_transport   TYPE trkorr
      RETURNING
        VALUE(rs_files) TYPE zif_abapgit_definitions=>ty_stage_files
      RAISING
        zcx_abapgit_exception .

    METHODS map_files
      IMPORTING
        !is_files       TYPE zif_abapgit_definitions=>ty_stage_files
      RETURNING
        VALUE(rt_files) TYPE ty_files_tt .

    METHODS count_objects
      IMPORTING
        !it_files       TYPE ty_files_tt
      RETURNING
        VALUE(rv_count) TYPE i .

    METHODS build_stage
      IMPORTING
        !is_files       TYPE zif_abapgit_definitions=>ty_stage_files
      RETURNING
        VALUE(ro_stage) TYPE REF TO zcl_abapgit_stage
      RAISING
        zcx_abapgit_exception .

    METHODS resolve_target_branch
      RETURNING
        VALUE(rv_branch) TYPE string
      RAISING
        zcx_abapgit_exception .

    METHODS remote_branch_exists
      IMPORTING
        !iv_branch       TYPE string
      RETURNING
        VALUE(rv_exists) TYPE abap_bool
      RAISING
        zcx_abapgit_exception .

    METHODS find_open_pull_request
      IMPORTING
        !iv_parent_request TYPE strkorr
        !iv_task_request   TYPE trkorr
      EXPORTING
        !ev_pr_number      TYPE int8
        !ev_pr_status      TYPE zde_pr_status
      RAISING
        zcx_abapgit_exception .

    METHODS link_pull_request
      IMPORTING
        !is_preview   TYPE ty_preview
        !iv_pr_number TYPE i
      RAISING
        zcx_abapgit_exception .

    METHODS determine_reviewers
      IMPORTING
        !iv_owner           TYPE tr_as4user
        !it_override        TYPE string_table
      RETURNING
        VALUE(rt_reviewers) TYPE string_table .

    METHODS determine_committer
      RETURNING
        VALUE(rs_user) TYPE zif_abapgit_git_definitions=>ty_git_user .

    METHODS build_pr_body
      IMPORTING
        !iv_transport  TYPE trkorr
        !iv_body       TYPE string
        !iv_count      TYPE i
      RETURNING
        VALUE(rv_body) TYPE string .

    METHODS escape_json_string
      IMPORTING
        !iv_input        TYPE string
      RETURNING
        VALUE(rv_output) TYPE string .

    METHODS resolve_user_and_repo
      RETURNING
        VALUE(rv_user_and_repo) TYPE string
      RAISING
        zcx_abapgit_exception .

    METHODS setup_credentials
      IMPORTING
        !iv_user  TYPE string
        !iv_token TYPE string
      RAISING
        zcx_abapgit_exception .

    METHODS write_log
      IMPORTING
        !iv_type    TYPE c DEFAULT 'I'
        !iv_message TYPE string
        !iv_detail  TYPE string OPTIONAL .

ENDCLASS.



CLASS zcl_abapgit_pr_service IMPLEMENTATION.


  METHOD create.

    DATA li_repo   TYPE REF TO zif_abapgit_repo.
    DATA lv_reason TYPE string.

    IF iv_repo_key IS NOT INITIAL.
      li_repo = zcl_abapgit_repo_srv=>get_instance( )->get( iv_repo_key ).
    ELSEIF iv_package IS NOT INITIAL.
      zcl_abapgit_repo_srv=>get_instance( )->get_repo_from_package(
        EXPORTING
          iv_package = iv_package
        IMPORTING
          ei_repo    = li_repo
          ev_reason  = lv_reason ).
      IF li_repo IS NOT BOUND.
        zcx_abapgit_exception=>raise( |No repository found for package { iv_package }: { lv_reason }| ).
      ENDIF.
    ELSE.
      zcx_abapgit_exception=>raise( 'Supply either a repository key or a package' ).
    ENDIF.

    CREATE OBJECT ro_service
      EXPORTING
        ii_repo = li_repo.

  ENDMETHOD.


  METHOD constructor.

    mi_repo = ii_repo.

    TRY.
        mi_repo_online ?= ii_repo.
      CATCH cx_sy_move_cast_error.
        zcx_abapgit_exception=>raise( 'Repository is offline, cannot push or raise a pull request' ).
    ENDTRY.

    mv_log_handle = zcl_abapgit_logging_utils=>create_application_log( iv_subobject = 'COMMIT' ).

  ENDMETHOD.


  METHOD preview.

    DATA ls_files TYPE zif_abapgit_definitions=>ty_stage_files.

    assert_transport_usable( is_request-transport ).

    " Branch resolution and status calculation both reach the remote, so authenticate first
    mv_user_and_repo = resolve_user_and_repo( ).
    setup_credentials( iv_user  = is_request-git_user
                       iv_token = is_request-git_token ).

    ls_files = collect_stage_files( is_request-transport ).

    rs_preview-repo_key       = mi_repo->get_key( ).
    rs_preview-repo_url       = mi_repo_online->get_url( ).
    rs_preview-package        = mi_repo->get_package( ).
    rs_preview-transport      = is_request-transport.
    rs_preview-parent_request = get_parent_request( is_request-transport ).
    rs_preview-owner          = get_request_owner( is_request-transport ).
    rs_preview-transport_text = get_transport_description( is_request-transport ).
    rs_preview-files          = map_files( ls_files ).
    rs_preview-file_count     = lines( rs_preview-files ).
    rs_preview-object_count   = count_objects( rs_preview-files ).

    IF rs_preview-parent_request <> is_request-transport.
      rs_preview-task_request = is_request-transport.
    ENDIF.

    IF is_request-branch_name IS INITIAL.
      rs_preview-source_branch = |{ c_branch_prefix }{ is_request-transport }|.
    ELSE.
      rs_preview-source_branch = is_request-branch_name.
    ENDIF.

    IF is_request-target_branch IS INITIAL.
      rs_preview-target_branch = resolve_target_branch( ).
    ELSE.
      rs_preview-target_branch = is_request-target_branch.
    ENDIF.

    rs_preview-reviewers = determine_reviewers( iv_owner    = rs_preview-owner
                                                it_override = is_request-reviewers ).

    " A previous run may already have pushed this transport
    rs_preview-branch_exists = remote_branch_exists( rs_preview-source_branch ).

    find_open_pull_request(
      EXPORTING
        iv_parent_request = rs_preview-parent_request
        iv_task_request   = rs_preview-task_request
      IMPORTING
        ev_pr_number      = rs_preview-open_pr_number
        ev_pr_status      = rs_preview-open_pr_status ).

  ENDMETHOD.


  METHOD stage_and_raise_pr.

    DATA ls_preview      TYPE ty_preview.
    DATA ls_files        TYPE zif_abapgit_definitions=>ty_stage_files.
    DATA lo_stage        TYPE REF TO zcl_abapgit_stage.
    DATA ls_commit       TYPE zif_abapgit_services_git=>ty_commit_fields.
    DATA ls_committer    TYPE zif_abapgit_git_definitions=>ty_git_user.
    DATA li_http_agent   TYPE REF TO zif_abapgit_http_agent.
    DATA lo_provider     TYPE REF TO zcl_abapgit_pr_enum_github.
    DATA lv_source_plain TYPE string.
    DATA lv_target_plain TYPE string.
    DATA lv_title        TYPE string.
    DATA lv_body         TYPE string.
    DATA lx_error        TYPE REF TO zcx_abapgit_exception.

    ls_preview = preview( is_request ).

    rs_result-transport     = is_request-transport.
    rs_result-source_branch = ls_preview-source_branch.
    rs_result-target_branch = ls_preview-target_branch.
    rs_result-object_count  = ls_preview-object_count.
    rs_result-file_count    = ls_preview-file_count.
    rs_result-reviewers     = ls_preview-reviewers.
    rs_result-log_handle    = mv_log_handle.

    IF ls_preview-file_count = 0.
      rs_result-success = abap_false.
      rs_result-message = |Nothing to stage for transport { is_request-transport }|.
      write_log( iv_type    = 'W'
                 iv_message = rs_result-message ).
      RETURN.
    ENDIF.

    IF is_request-commit_message IS INITIAL.
      zcx_abapgit_exception=>raise( 'Commit message is required' ).
    ENDIF.

    IF is_request-dry_run = abap_true.
      rs_result-success = abap_true.
      IF ls_preview-open_pr_number IS INITIAL.
        rs_result-message = |Dry run: { ls_preview-object_count } object(s) in { ls_preview-file_count } file(s) | &&
                            |would be pushed to { ls_preview-source_branch } and a PR raised against | &&
                            |{ ls_preview-target_branch }|.
      ELSE.
        rs_result-pr_number = ls_preview-open_pr_number.
        rs_result-pr_reused = abap_true.
        rs_result-message = |Dry run: { ls_preview-object_count } object(s) in { ls_preview-file_count } file(s) | &&
                            |would be pushed to { ls_preview-source_branch }, updating open PR | &&
                            |{ ls_preview-open_pr_number } ({ ls_preview-open_pr_status })|.
      ENDIF.
      RETURN.
    ENDIF.

    " preview( ) has already resolved the repository and set up credentials
    TRY.
        ls_files = collect_stage_files( is_request-transport ).
        lo_stage = build_stage( ls_files ).

        IF ls_preview-branch_exists = abap_true.
          write_log( iv_message = 'Reusing existing feature branch'
                     iv_detail  = ls_preview-source_branch ).
          mi_repo_online->select_branch( ls_preview-source_branch ).
        ELSE.
          write_log( iv_message = 'Creating feature branch'
                     iv_detail  = ls_preview-source_branch ).
          " create_branch also switches the repository onto the new branch
          mi_repo_online->create_branch( ls_preview-source_branch ).
        ENDIF.

        ls_committer = determine_committer( ).

        ls_commit-repo_key        = mi_repo->get_key( ).
        ls_commit-committer_name  = ls_committer-name.
        ls_commit-committer_email = ls_committer-email.
        ls_commit-author_name     = ls_committer-name.
        ls_commit-author_email    = ls_committer-email.
        ls_commit-comment         = is_request-commit_message.
        ls_commit-body            = is_request-commit_body.

        zcl_abapgit_services_git=>commit( ii_repo_online = mi_repo_online
                                          is_commit      = ls_commit
                                          io_stage       = lo_stage ).

        write_log( iv_type    = 'S'
                   iv_message = 'Commit pushed'
                   iv_detail  = |{ ls_preview-object_count } object(s), { ls_preview-file_count } file(s)| ).

        " Switch back so the next change starts from the release branch again
        mi_repo_online->select_branch( ls_preview-target_branch ).

      CATCH zcx_abapgit_exception INTO lx_error.
        write_log( iv_type    = 'E'
                   iv_message = 'Push failed'
                   iv_detail  = lx_error->get_text( ) ).
        RAISE EXCEPTION lx_error.
    ENDTRY.

    lv_source_plain = zcl_abapgit_git_branch_utils=>get_display_name( ls_preview-source_branch ).
    lv_target_plain = zcl_abapgit_git_branch_utils=>get_display_name( ls_preview-target_branch ).

    " An open pull request already tracks this branch, so the commit above is enough
    IF ls_preview-open_pr_number IS NOT INITIAL.
      rs_result-pr_number = ls_preview-open_pr_number.
      rs_result-pr_url    = |https://github.com/{ mv_user_and_repo }/pull/{ ls_preview-open_pr_number }|.
      rs_result-pr_reused = abap_true.
      rs_result-success   = abap_true.
      rs_result-message   = |Pushed { ls_preview-object_count } object(s) to existing PR | &&
                            |{ ls_preview-open_pr_number } ({ ls_preview-open_pr_status }) on { lv_source_plain }|.

      write_log( iv_type    = 'S'
                 iv_message = |Pushed to existing pull request { ls_preview-open_pr_number }|
                 iv_detail  = rs_result-pr_url ).
      RETURN.
    ENDIF.

    lv_title = escape_json_string( is_request-pr_title ).
    IF lv_title IS INITIAL.
      lv_title = escape_json_string( is_request-commit_message ).
    ENDIF.

    lv_body = escape_json_string( build_pr_body( iv_transport = is_request-transport
                                                 iv_body      = is_request-pr_body
                                                 iv_count     = ls_preview-object_count ) ).

    li_http_agent = zcl_abapgit_http_agent=>create( ).

    CREATE OBJECT lo_provider
      EXPORTING
        iv_user_and_repo = mv_user_and_repo
        ii_http_agent    = li_http_agent.

    rs_result-pr_number = lo_provider->create_pull_request( iv_title = lv_title
                                                            iv_body  = lv_body
                                                            iv_head  = lv_source_plain
                                                            iv_base  = lv_target_plain ).

    rs_result-pr_url = |https://github.com/{ mv_user_and_repo }/pull/{ rs_result-pr_number }|.

    write_log( iv_type    = 'S'
               iv_message = |Pull request { rs_result-pr_number } created|
               iv_detail  = rs_result-pr_url ).

    link_pull_request( is_preview   = ls_preview
                       iv_pr_number = rs_result-pr_number ).

    IF ls_preview-reviewers IS NOT INITIAL.
      lo_provider->assign_reviewers( iv_pull_number = rs_result-pr_number
                                     it_reviewers   = ls_preview-reviewers ).
      write_log( iv_message = 'Reviewers assigned'
                 iv_detail  = |{ lines( ls_preview-reviewers ) } reviewer(s)| ).
    ENDIF.

    lo_provider->ready_for_review( rs_result-pr_number ).

    rs_result-success = abap_true.
    rs_result-message = |PR { rs_result-pr_number } raised for { is_request-transport }: | &&
                        |{ lv_source_plain } -> { lv_target_plain }|.

  ENDMETHOD.


  METHOD assert_transport_usable.

    DATA lv_status TYPE trstatus.

    IF iv_transport IS INITIAL.
      zcx_abapgit_exception=>raise( 'A transport request or task is required' ).
    ENDIF.

    SELECT SINGLE trstatus FROM e070
      INTO @lv_status
      WHERE trkorr = @iv_transport.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |Transport { iv_transport } does not exist| ).
    ENDIF.

    " D = modifiable, L = modifiable/protected, anything else is released or releasing
    IF lv_status <> 'D' AND lv_status <> 'L'.
      zcx_abapgit_exception=>raise( |Transport { iv_transport } is not modifiable (status { lv_status })| ).
    ENDIF.

  ENDMETHOD.


  METHOD get_parent_request.

    " A task carries its parent in STRKORR, a request is its own parent
    SELECT SINGLE strkorr FROM e070
      INTO @rv_parent
      WHERE trkorr = @iv_request.

    IF sy-subrc <> 0 OR rv_parent IS INITIAL.
      rv_parent = iv_request.
    ENDIF.

  ENDMETHOD.


  METHOD get_request_owner.

    SELECT SINGLE as4user FROM e070
      INTO @rv_owner
      WHERE trkorr = @iv_request.
    IF sy-subrc <> 0.
      CLEAR rv_owner.
    ENDIF.

  ENDMETHOD.


  METHOD get_transport_description.

    DATA lv_as4text TYPE e07t-as4text.

    SELECT SINGLE as4text FROM e07t
      INTO @lv_as4text
      WHERE trkorr = @iv_transport
        AND langu  = @sy-langu.
    IF sy-subrc <> 0.
      SELECT SINGLE as4text FROM e07t
        INTO @lv_as4text
        WHERE trkorr = @iv_transport
          AND langu  = 'E'.
      IF sy-subrc <> 0.
        CLEAR lv_as4text.
      ENDIF.
    ENDIF.

    rv_description = lv_as4text.

  ENDMETHOD.


  METHOD build_object_filter.

    DATA lo_filter   TYPE REF TO zcl_abapgit_object_filter_tran.
    DATA lt_r_trkorr TYPE zif_abapgit_definitions=>ty_trrngtrkor_tt.
    DATA ls_r_trkorr LIKE LINE OF lt_r_trkorr.

    ls_r_trkorr-sign   = 'I'.
    ls_r_trkorr-option = 'EQ'.
    ls_r_trkorr-low    = iv_transport.
    APPEND ls_r_trkorr TO lt_r_trkorr.

    CREATE OBJECT lo_filter.

    lo_filter->set_filter_values( iv_package  = mi_repo->get_package( )
                                  it_r_trkorr = lt_r_trkorr ).

    ri_filter = lo_filter.

  ENDMETHOD.


  METHOD collect_stage_files.

    rs_files = zcl_abapgit_stage_logic=>get_stage_logic( )->get(
      ii_repo_online = mi_repo
      ii_obj_filter  = build_object_filter( iv_transport ) ).

  ENDMETHOD.


  METHOD map_files.

    FIELD-SYMBOLS <ls_local>  LIKE LINE OF is_files-local.
    FIELD-SYMBOLS <ls_remote> LIKE LINE OF is_files-remote.
    FIELD-SYMBOLS <ls_file>   LIKE LINE OF rt_files.

    LOOP AT is_files-local ASSIGNING <ls_local>.
      APPEND INITIAL LINE TO rt_files ASSIGNING <ls_file>.
      <ls_file>-obj_type = <ls_local>-item-obj_type.
      <ls_file>-obj_name = <ls_local>-item-obj_name.
      <ls_file>-path     = <ls_local>-file-path.
      <ls_file>-filename = <ls_local>-file-filename.
      <ls_file>-method   = zif_abapgit_definitions=>c_method-add.
    ENDLOOP.

    LOOP AT is_files-remote ASSIGNING <ls_remote>.
      APPEND INITIAL LINE TO rt_files ASSIGNING <ls_file>.
      <ls_file>-path     = <ls_remote>-path.
      <ls_file>-filename = <ls_remote>-filename.
      <ls_file>-method   = zif_abapgit_definitions=>c_method-rm.
    ENDLOOP.

  ENDMETHOD.


  METHOD count_objects.

    TYPES: BEGIN OF lty_key,
             obj_type TYPE trobjtype,
             obj_name TYPE sobj_name,
           END OF lty_key.

    DATA lt_keys TYPE HASHED TABLE OF lty_key WITH UNIQUE KEY obj_type obj_name.
    DATA ls_key  TYPE lty_key.

    FIELD-SYMBOLS <ls_file> LIKE LINE OF it_files.

    " Deleted remote files carry no item, so they cannot be counted as objects
    LOOP AT it_files ASSIGNING <ls_file> WHERE obj_name IS NOT INITIAL.
      ls_key-obj_type = <ls_file>-obj_type.
      ls_key-obj_name = <ls_file>-obj_name.
      INSERT ls_key INTO TABLE lt_keys.
    ENDLOOP.

    rv_count = lines( lt_keys ).

  ENDMETHOD.


  METHOD build_stage.

    FIELD-SYMBOLS <ls_local>  LIKE LINE OF is_files-local.
    FIELD-SYMBOLS <ls_remote> LIKE LINE OF is_files-remote.

    CREATE OBJECT ro_stage.

    LOOP AT is_files-local ASSIGNING <ls_local>.
      ro_stage->add( iv_path     = <ls_local>-file-path
                     iv_filename = <ls_local>-file-filename
                     iv_data     = <ls_local>-file-data ).
    ENDLOOP.

    LOOP AT is_files-remote ASSIGNING <ls_remote>.
      ro_stage->rm( iv_path     = <ls_remote>-path
                    iv_filename = <ls_remote>-filename ).
    ENDLOOP.

  ENDMETHOD.


  METHOD resolve_target_branch.

    DATA lt_branches TYPE zif_abapgit_git_definitions=>ty_git_branch_list_tt.
    DATA ls_branch   TYPE zif_abapgit_git_definitions=>ty_git_branch.

    lt_branches = zcl_abapgit_git_factory=>get_git_transport(
      )->branches( mi_repo_online->get_url( )
      )->get_branches_only( ).

    " A release branch for this system wins over the repository default
    LOOP AT lt_branches INTO ls_branch.
      IF ls_branch-display_name CP |release/{ to_upper( sy-sysid ) }*|.
        rv_branch = ls_branch-name.
        RETURN.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_branches INTO ls_branch.
      IF ls_branch-display_name = 'main' OR ls_branch-display_name = 'master'.
        rv_branch = ls_branch-name.
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_branch = zcl_abapgit_git_factory=>get_git_transport(
      )->branches( mi_repo_online->get_url( )
      )->get_head_symref( ).

  ENDMETHOD.


  METHOD remote_branch_exists.

    DATA lt_branches TYPE zif_abapgit_git_definitions=>ty_git_branch_list_tt.
    DATA lv_plain    TYPE string.

    FIELD-SYMBOLS <ls_branch> LIKE LINE OF lt_branches.

    lv_plain = zcl_abapgit_git_branch_utils=>get_display_name( iv_branch ).

    lt_branches = zcl_abapgit_git_factory=>get_git_transport(
      )->branches( mi_repo_online->get_url( )
      )->get_branches_only( ).

    LOOP AT lt_branches ASSIGNING <ls_branch>.
      IF <ls_branch>-display_name = lv_plain.
        rv_exists = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD find_open_pull_request.

    DATA lt_links TYPE zcl_abapgit_pr_status_manager=>tt_pr_links.

    FIELD-SYMBOLS <ls_link> LIKE LINE OF lt_links.

    CLEAR: ev_pr_number, ev_pr_status.

    IF iv_parent_request IS INITIAL.
      RETURN.
    ENDIF.

    " GitHub owns the truth, the table only caches it. Reconcile before trusting a row,
    " otherwise a PR merged outside SAP still looks reusable here.
    zcl_abapgit_pr_status_manager=>sync_with_github(
      iv_parent_request = iv_parent_request
      iv_task_request   = iv_task_request
      iv_repo_url       = mi_repo_online->get_url( )
      iv_log_handle     = mv_log_handle ).

    lt_links = zcl_abapgit_pr_status_manager=>get_pr_tr_linkage(
                 iv_parent_request = iv_parent_request
                 iv_task_request   = iv_task_request ).

    " An empty task selects every PR under the parent, so match the task exactly
    " to avoid adopting a sibling task's pull request. Merged or closed ones need a new PR.
    LOOP AT lt_links ASSIGNING <ls_link>
      WHERE task_request = iv_task_request
        AND pr_status <> zcl_abapgit_pr_status_manager=>c_pr_status-merged
        AND pr_status <> zcl_abapgit_pr_status_manager=>c_pr_status-closed.
      ev_pr_number = <ls_link>-pr_id.
      ev_pr_status = <ls_link>-pr_status.
      RETURN.
    ENDLOOP.

  ENDMETHOD.


  METHOD link_pull_request.

    DATA lt_links TYPE zcl_abapgit_pr_status_manager=>tt_pr_links.

    FIELD-SYMBOLS <ls_link> LIKE LINE OF lt_links.

    " ZDT_PULL_REQUEST is keyed on parent and task only, so one task can hold one link.
    " A finished PR has to give up its slot before the follow-up PR can take it.
    lt_links = zcl_abapgit_pr_status_manager=>get_pr_tr_linkage(
                 iv_parent_request = is_preview-parent_request
                 iv_task_request   = is_preview-task_request ).

    LOOP AT lt_links ASSIGNING <ls_link> WHERE task_request = is_preview-task_request.
      zcl_abapgit_pr_status_manager=>delete_pr_link(
        iv_parent_request = <ls_link>-parent_request
        iv_task_request   = <ls_link>-task_request
        iv_pr_id          = <ls_link>-pr_id ).

      write_log( iv_type    = 'W'
                 iv_message = |PR link { <ls_link>-pr_id } replaced by { iv_pr_number }|
                 iv_detail  = |Previous status { <ls_link>-pr_status }, history stays on GitHub| ).
    ENDLOOP.

    zcl_abapgit_pr_status_manager=>create_pr_link(
      iv_parent_request = is_preview-parent_request
      iv_task_request   = is_preview-task_request
      iv_pr_id          = CONV int8( iv_pr_number )
      iv_pr_status      = zcl_abapgit_pr_status_manager=>c_pr_status-open
      iv_owner          = is_preview-owner
      iv_log_handle     = mv_log_handle ).

  ENDMETHOD.


  METHOD determine_reviewers.

    DATA lt_tvarvc TYPE STANDARD TABLE OF tvarvc WITH DEFAULT KEY.
    DATA ls_tvarvc TYPE tvarvc.
    DATA lv_self   TYPE string.

    IF it_override IS NOT INITIAL.
      rt_reviewers = it_override.
    ELSE.
      SELECT * FROM tvarvc
        INTO TABLE @lt_tvarvc
        WHERE name = @c_tvarvc_reviewers.
      IF sy-subrc = 0.
        LOOP AT lt_tvarvc INTO ls_tvarvc.
          APPEND to_lower( ls_tvarvc-low ) TO rt_reviewers.
        ENDLOOP.
      ENDIF.

      IF rt_reviewers IS INITIAL.
        APPEND c_default_reviewer TO rt_reviewers.
      ENDIF.
    ENDIF.

    " Nobody reviews their own pull request
    IF iv_owner IS NOT INITIAL.
      lv_self = to_lower( |{ iv_owner }{ c_github_user_suffix }| ).
    ELSE.
      lv_self = to_lower( |{ sy-uname }{ c_github_user_suffix }| ).
    ENDIF.

    DELETE rt_reviewers WHERE table_line = lv_self.

    IF rt_reviewers IS INITIAL.
      APPEND c_default_reviewer TO rt_reviewers.
    ENDIF.

  ENDMETHOD.


  METHOD determine_committer.

    DATA li_user        TYPE REF TO zif_abapgit_persist_user.
    DATA li_user_record TYPE REF TO zif_abapgit_user_record.
    DATA lv_url         TYPE string.

    lv_url  = mi_repo_online->get_url( ).
    li_user = zcl_abapgit_persist_factory=>get_user( ).

    rs_user-name  = li_user->get_repo_git_user_name( lv_url ).
    rs_user-email = li_user->get_repo_git_user_email( lv_url ).

    IF rs_user-name IS INITIAL.
      rs_user-name = li_user->get_default_git_user_name( ).
    ENDIF.
    IF rs_user-email IS INITIAL.
      rs_user-email = li_user->get_default_git_user_email( ).
    ENDIF.

    IF rs_user-name IS INITIAL OR rs_user-email IS INITIAL.
      li_user_record = zcl_abapgit_env_factory=>get_user_record( ).
      IF rs_user-name IS INITIAL.
        rs_user-name = li_user_record->get_name( sy-uname ).
      ENDIF.
      IF rs_user-email IS INITIAL.
        rs_user-email = li_user_record->get_email( sy-uname ).
      ENDIF.
    ENDIF.

    IF rs_user-name IS INITIAL.
      rs_user-name = sy-uname.
    ENDIF.
    IF rs_user-email IS INITIAL.
      rs_user-email = |{ sy-uname }@localhost|.
    ENDIF.

  ENDMETHOD.


  METHOD build_pr_body.

    DATA lv_parent TYPE strkorr.
    DATA lv_owner  TYPE tr_as4user.
    DATA lv_nl     TYPE string.

    lv_nl     = cl_abap_char_utilities=>newline.
    lv_parent = get_parent_request( iv_transport ).
    lv_owner  = get_request_owner( iv_transport ).

    " Reviewers need to see which task of which parent request they are reviewing,
    " because several developers raise separate PRs under one parent request
    IF lv_parent = iv_transport.
      rv_body = |**Transport Request:** { iv_transport }{ lv_nl }|.
    ELSE.
      rv_body = |**Parent Request:** { lv_parent }{ lv_nl }| &&
                |**Task:** { iv_transport }{ lv_nl }|.
    ENDIF.

    rv_body = rv_body &&
              |**Owner:** { lv_owner }{ lv_nl }| &&
              |**Description:** { get_transport_description( iv_transport ) }{ lv_nl }| &&
              |**Objects:** { iv_count }{ lv_nl }{ lv_nl }| &&
              iv_body.

  ENDMETHOD.


  METHOD escape_json_string.

    IF iv_input IS INITIAL.
      RETURN.
    ENDIF.

    rv_output = iv_input.

    " Backslash must be escaped first, otherwise it double-escapes the escapes added below
    REPLACE ALL OCCURRENCES OF '\' IN rv_output WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_output WITH '\"'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN rv_output WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_output WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN rv_output WITH '\t'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>vertical_tab IN rv_output WITH '\t'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>backspace IN rv_output WITH '\b'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>form_feed IN rv_output WITH '\f'.

  ENDMETHOD.


  METHOD resolve_user_and_repo.

    DATA lv_url  TYPE string.
    DATA lv_user TYPE string.
    DATA lv_repo TYPE string.

    lv_url = mi_repo_online->get_url( ).

    FIND PCRE 'github\.com[/:]([^/]+)/([^/]+)' IN lv_url SUBMATCHES lv_user lv_repo.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |Automatic PR creation is only supported for GitHub, got { lv_url }| ).
    ENDIF.

    lv_repo = replace( val  = lv_repo
                       pcre = '\.git$'
                       with = '' ).

    rv_user_and_repo = |{ lv_user }/{ lv_repo }|.

  ENDMETHOD.


  METHOD setup_credentials.

    DATA lv_url  TYPE string.
    DATA lv_user TYPE string.

    lv_url = mi_repo_online->get_url( ).

    " Each developer authenticates with their own token, so nothing is shared system wide.
    " With no token supplied, fall back to what abapGit already stored for this user and repository.
    IF iv_token IS INITIAL.
      IF zcl_abapgit_login_manager=>load( lv_url ) IS INITIAL.
        zcx_abapgit_exception=>raise(
          |No GitHub token supplied and none stored for { lv_url }. | &&
          |Pass your own token in GIT_TOKEN, or log on to the repository once in abapGit.| ).
      ENDIF.
      RETURN.
    ENDIF.

    lv_user = iv_user.
    IF lv_user IS INITIAL.
      lv_user = 'x-access-token'.
    ENDIF.

    zcl_abapgit_login_manager=>set( iv_uri      = lv_url
                                    iv_username = lv_user
                                    iv_password = iv_token ).

    " The PR provider authenticates against the REST API host, not the clone URL
    zcl_abapgit_login_manager=>set( iv_uri      = |https://api.github.com/repos/{ mv_user_and_repo }|
                                    iv_username = lv_user
                                    iv_password = iv_token ).

  ENDMETHOD.


  METHOD write_log.

    TRY.
        zcl_abapgit_logging_utils=>write_application_log( iv_log_handle = mv_log_handle
                                                          iv_log_type   = iv_type
                                                          iv_message    = iv_message
                                                          iv_detail     = iv_detail ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
        " Logging must never break the operation it is logging
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
