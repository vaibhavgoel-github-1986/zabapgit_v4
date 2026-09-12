@EndUserText.label: 'Stage a transport and raise a GitHub pull request'
define root custom entity ZCE_GIT_PR
{
      // Synthetic key, filled by the API
  key request_id      : abap.char(32);

      // What to push. Supply either devclass or repo_key.
      devclass        : devclass;
      repo_key        : abap.char(12);
      transport       : trkorr;

      // Optional overrides. Defaults are feature/<transport> and the
      // release branch of this system, falling back to main or master.
      branch_name     : abap.string(0);
      target_branch   : abap.string(0);
      commit_message  : abap.string(0);
      commit_body     : abap.string(0);
      pr_title        : abap.string(0);
      pr_body         : abap.string(0);

      // Caller's own GitHub credentials. Never persisted, never logged.
      git_user        : abap.string(0);
      git_token       : abap.string(0);

      // X = resolve everything and report, change nothing
      preview_only    : abap.char(1);
      dry_run         : abap.char(1);

      // Result
      success         : abap.char(1);
      pr_number       : abap.int4;
      pr_url          : abap.string(0);
      source_branch   : abap.string(0);
      resolved_target : abap.string(0);
      repo_url        : abap.string(0);
      parent_request  : trkorr;
      task_request    : trkorr;
      owner           : tr_as4user;
      transport_text  : abap.string(0);
      object_count    : abap.int4;
      file_count      : abap.int4;
      reviewers       : abap.string(0);
      files           : abap.string(0);
      message         : abap.string(0);
}
