-- =============================================================================
-- consent_log  (PRD 6.1 "consent_log" + 4.4 Consent Gate)
-- Immutable, append-only record of every consent acceptance. Retained 7 years
-- as a legal obligation; never user-deletable and exempt from GDPR erasure
-- (PRD 6.2 / 7.2). IP and device are stored hashed only (PRD 7.2).
--
-- NOTE: migration 07 later relaxes the FK to ON DELETE SET NULL and replaces
-- the immutability triggers with a GUC-guarded guard, to reconcile 7-year
-- retention with GDPR account erasure. See that migration for rationale.
-- =============================================================================
create table public.consent_log (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references public.profiles (id) on delete restrict,
  consent_version         text not null,
  accepted_at             timestamptz not null default now(),
  ip_hash                 text,                      -- hashed IP only — no raw PII (PRD 7.2)
  device_fingerprint_hash text                       -- hashed device fingerprint only (PRD 7.2)
);

comment on table public.consent_log is 'Immutable append-only consent history (PRD 6.1). 7-year retention; exempt from erasure (PRD 6.2/7.2).';
comment on column public.consent_log.ip_hash is 'Hashed IP only to prevent re-identification from logs (PRD 7.2).';

create index idx_consent_log_user_id on public.consent_log (user_id);

-- Enforce immutability at the database level: block UPDATE and DELETE entirely.
create or replace function public.prevent_mutation()
  returns trigger
  language plpgsql
as $$
begin
  raise exception 'Table %.% is append-only and cannot be modified or deleted',
    tg_table_schema, tg_table_name;
end;
$$;

create trigger trg_consent_log_no_update
  before update on public.consent_log
  for each row execute function public.prevent_mutation();

create trigger trg_consent_log_no_delete
  before delete on public.consent_log
  for each row execute function public.prevent_mutation();

-- =============================================================================
-- audit_event  (PRD 6.1 "audit_event")
-- Append-only operational audit trail. user_id nullable (some events are
-- pre-auth). No raw PII — metadata is hashed/minimised. 3-year retention,
-- auto-purged, not user-accessible (PRD 6.2).
-- =============================================================================
create table public.audit_event (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references public.profiles (id) on delete set null,  -- nullable; survives profile deletion as anonymised
  event_type   public.audit_event_type not null,
  entity_type  public.audit_entity_type,
  entity_id    uuid,
  occurred_at  timestamptz not null default now(),
  metadata     jsonb not null default '{}'::jsonb   -- minimised/hashed metadata only — no raw PII (PRD 7.2)
);

comment on table public.audit_event is 'Append-only operational audit trail (PRD 6.1). 3-year retention; not user-accessible (PRD 6.2).';

create index idx_audit_event_user_id on public.audit_event (user_id);
create index idx_audit_event_occurred_at on public.audit_event (occurred_at);
create index idx_audit_event_type on public.audit_event (event_type);

create trigger trg_audit_event_no_update
  before update on public.audit_event
  for each row execute function public.prevent_mutation();
