-- Address advisor warnings.

-- 1) Pin search_path on trigger helper functions (they already schema-qualify
--    every object reference, so empty search_path is safe).
alter function public.prevent_mutation()    set search_path = '';
alter function public.enforce_report_limit() set search_path = '';
alter function public.guard_consent_log()    set search_path = '';

-- 2) These SECURITY DEFINER functions must NOT be callable from the public API.
--    handle_new_user runs only via the auth.users trigger; the retention_* funcs
--    run only via pg_cron (as the postgres owner). Revoke EXECUTE from API roles;
--    trigger and cron execution are unaffected by these grants.
revoke execute on function public.handle_new_user()                     from public, anon, authenticated;
revoke execute on function public.retention_purge_soft_deleted_reports() from public, anon, authenticated;
revoke execute on function public.retention_purge_expired_reports()      from public, anon, authenticated;
revoke execute on function public.retention_purge_audit_events()         from public, anon, authenticated;
revoke execute on function public.retention_purge_consent_log()          from public, anon, authenticated;
revoke execute on function public.retention_purge_deleted_accounts()     from public, anon, authenticated;
