-- =============================================================================
-- Retention & erasure automation (PRD 6.2 Data retention + 7.2 GDPR).
--
-- Design note on the consent_log vs. erasure tension:
--   * consent_log must be immutable/append-only AND retained 7 years AND exempt
--     from user erasure (PRD 6.2).
--   * BUT an account hard-delete (30-day grace) must remove the person's PII.
--   The resolution: on account erasure we ANONYMISE the consent record (user_id
--   -> null) rather than delete it, so the immutable consent fact (version +
--   timestamp + hashes) survives 7 years with no link to the erased person.
--   Direct user UPDATE/DELETE remain blocked; only trusted backend routines
--   that set the `app.compliance_mode` GUC may mutate it.
-- =============================================================================

-- Allow the consent FK to be anonymised (not cascade-deleted) on profile removal.
alter table public.consent_log
  drop constraint consent_log_user_id_fkey;
alter table public.consent_log
  alter column user_id drop not null;
alter table public.consent_log
  add constraint consent_log_user_id_fkey
    foreign key (user_id) references public.profiles (id) on delete set null;

-- Replace the blunt immutability triggers with a GUC-guarded guard so trusted
-- compliance routines can anonymise/purge, while all normal traffic is blocked.
drop trigger if exists trg_consent_log_no_update on public.consent_log;
drop trigger if exists trg_consent_log_no_delete on public.consent_log;

create or replace function public.guard_consent_log()
  returns trigger
  language plpgsql
as $$
begin
  if coalesce(current_setting('app.compliance_mode', true), 'off') <> 'on' then
    raise exception 'consent_log is append-only; % blocked outside compliance mode', tg_op;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger trg_consent_log_guard_update
  before update on public.consent_log
  for each row execute function public.guard_consent_log();

create trigger trg_consent_log_guard_delete
  before delete on public.consent_log
  for each row execute function public.guard_consent_log();

-- ---------------------------------------------------------------------------
-- Retention functions. All run server-side (security definer, owned by the
-- migration role) and are intended to be invoked by pg_cron.
-- ---------------------------------------------------------------------------

-- 30-day purge of soft-deleted reports (PRD 6.2: "soft-deleted but purged after
-- 30 days"). Cascades to markers, ai_explanations, ai_summaries.
create or replace function public.retention_purge_soft_deleted_reports()
  returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare n integer;
begin
  delete from public.reports
  where deleted_at is not null
    and deleted_at < now() - interval '30 days';
  get diagnostics n = row_count;
  return n;
end;
$$;

-- 24-month auto-purge of parsed reports/markers (PRD 6.2: "max 24 months").
create or replace function public.retention_purge_expired_reports()
  returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare n integer;
begin
  delete from public.reports
  where uploaded_at < now() - interval '24 months';
  get diagnostics n = row_count;
  return n;
end;
$$;

-- 3-year auto-purge of audit events (PRD 6.2).
create or replace function public.retention_purge_audit_events()
  returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare n integer;
begin
  delete from public.audit_event
  where occurred_at < now() - interval '3 years';
  get diagnostics n = row_count;
  return n;
end;
$$;

-- 7-year purge of consent log (PRD 6.2 legal obligation). Requires compliance mode.
create or replace function public.retention_purge_consent_log()
  returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare n integer;
begin
  perform set_config('app.compliance_mode', 'on', true);
  delete from public.consent_log
  where accepted_at < now() - interval '7 years';
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Account hard-delete after the 30-day grace period (PRD 6.2). Removes the
-- auth user (source-of-truth email) which cascades to profiles and all health
-- data; consent_log is anonymised (user_id -> null) under compliance mode.
create or replace function public.retention_purge_deleted_accounts()
  returns integer
  language plpgsql
  security definer
  set search_path = public, auth
as $$
declare n integer;
begin
  perform set_config('app.compliance_mode', 'on', true);
  delete from auth.users
  where id in (
    select id from public.profiles
    where deleted_at is not null
      and deleted_at < now() - interval '30 days'
  );
  get diagnostics n = row_count;
  return n;
end;
$$;
