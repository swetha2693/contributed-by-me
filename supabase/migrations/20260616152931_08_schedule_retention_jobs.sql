-- Schedule the PRD 6.2 retention jobs with pg_cron. All run daily; each function
-- is idempotent and only acts on rows past their retention window.
create extension if not exists pg_cron;

select cron.schedule(
  'purge-soft-deleted-reports',
  '15 2 * * *',                         -- daily 02:15 UTC
  $$select public.retention_purge_soft_deleted_reports();$$
);

select cron.schedule(
  'purge-expired-reports',
  '30 2 * * *',                         -- daily 02:30 UTC
  $$select public.retention_purge_expired_reports();$$
);

select cron.schedule(
  'purge-audit-events',
  '45 2 * * *',                         -- daily 02:45 UTC
  $$select public.retention_purge_audit_events();$$
);

select cron.schedule(
  'purge-consent-log',
  '0 3 * * *',                          -- daily 03:00 UTC
  $$select public.retention_purge_consent_log();$$
);

select cron.schedule(
  'purge-deleted-accounts',
  '15 3 * * *',                         -- daily 03:15 UTC
  $$select public.retention_purge_deleted_accounts();$$
);
