-- =============================================================================
-- profiles  (PRD 6.1 "user")
-- Linked 1:1 to Supabase auth.users. PII is minimised: we keep only a salted
-- email hash in app data; the real email lives in auth.users and is governed
-- by Supabase. Holds the user's CURRENT consent snapshot; full history lives
-- in consent_log.
-- =============================================================================
create table public.profiles (
  id                  uuid primary key references auth.users (id) on delete cascade,
  email_hash          text unique,                 -- salted hash only (PRD: "email stored as salted hash only")
  consent_accepted_at timestamptz,                 -- null until the consent gate is accepted (PRD 4.4)
  consent_version     text,                        -- version of disclaimer text accepted
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz                  -- account deletion request time; hard-deleted after 30-day grace (PRD 6.2)
);

comment on table public.profiles is 'App-level user record (PRD 6.1 "user"). 1:1 with auth.users; PII minimised.';
comment on column public.profiles.email_hash is 'Salted hash of email only — no raw PII stored at app level.';
comment on column public.profiles.consent_accepted_at is 'Timestamp of current consent acceptance; gate re-appears after 12 months or new device (PRD 4.4).';

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function extensions.moddatetime (updated_at);

-- =============================================================================
-- reports  (PRD 6.1 "report" + 4.3 Report History)
-- A saved lab report. Raw uploaded text is encrypted at rest by the app layer
-- (AES-256) and is only persisted when the user explicitly saves; otherwise the
-- session is in-memory only. Soft-deleted, then purged after 30 days (PRD 6.2).
-- Authenticated users may save up to 12 reports (PRD 4.3) — enforced by trigger.
-- =============================================================================
create table public.reports (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles (id) on delete cascade,
  label              text,                          -- optional user label, e.g. "Annual blood panel Mar 2026" (PRD 4.3)
  source_type        public.report_source_type not null,
  report_date        date,                          -- date printed on the report (may differ from upload)
  uploaded_at        timestamptz not null default now(),
  raw_text_encrypted bytea,                         -- AES-256 ciphertext, app-encrypted; null unless saved (PRD 6.2)
  parser_version     text not null,                 -- rule-based parser version for auditability (PRD 4.1.2)
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz                    -- soft delete; purged after 30 days (PRD 6.2)
);

comment on table public.reports is 'Saved lab report (PRD 6.1 "report"). Raw text app-encrypted at rest; max 12 active per user (PRD 4.3).';
comment on column public.reports.raw_text_encrypted is 'AES-256 ciphertext produced by the app before insert. Session-only reports are never written here (PRD 6.2).';

create index idx_reports_user_id on public.reports (user_id) where deleted_at is null;
create index idx_reports_user_uploaded on public.reports (user_id, uploaded_at desc) where deleted_at is null;

create trigger trg_reports_updated_at
  before update on public.reports
  for each row execute function extensions.moddatetime (updated_at);

-- =============================================================================
-- markers  (PRD 6.1 "marker" + 4.1.2 parser behaviour)
-- One row per extracted marker. value_text preserves the raw parsed value so
-- non-numeric values like "< 5" are never lost (PRD 7.3 edge case); value_num
-- holds the numeric form when one can be derived for range comparison.
-- =============================================================================
create table public.markers (
  id                 uuid primary key default gen_random_uuid(),
  report_id          uuid not null references public.reports (id) on delete cascade,
  name               text not null,                 -- marker name as parsed (e.g. "HbA1c")
  value_text         text not null,                 -- raw value exactly as parsed, incl. "< 5", ranges, etc.
  value_num          numeric,                       -- numeric form when derivable; null for non-numeric values
  unit               text,
  range_low          numeric,
  range_high         numeric,
  flag               public.lab_flag,               -- H / L / normal; null when not determinable
  is_critical        boolean not null default false,-- value > 2x outside range; AI explainer suppressed, NHS 111 signpost (PRD 7.1/7.3)
  is_recognised      boolean not null default true,  -- false => "not recognised, review manually" badge (PRD 4.1.3)
  parser_confidence  numeric not null check (parser_confidence >= 0 and parser_confidence <= 1), -- (PRD 4.1.2)
  needs_manual_review boolean generated always as (parser_confidence < 0.6) stored, -- below 0.6 -> manual confirmation (PRD 4.1.2)
  position_in_report integer,                        -- ordering within the source report
  created_at         timestamptz not null default now()
);

comment on table public.markers is 'Extracted marker rows (PRD 6.1 "marker"). Rule-based parser output; no FK to AI output by design.';
comment on column public.markers.value_text is 'Raw parsed value preserved verbatim so range/string values like "< 5" are never dropped (PRD 7.3).';
comment on column public.markers.is_critical is 'True when value is >2x outside range; AI explainer is NOT triggered and user is directed to NHS 111 (PRD 7.1/7.3).';
comment on column public.markers.needs_manual_review is 'Derived: parser_confidence < 0.6 surfaces the marker for manual confirmation (PRD 4.1.2).';

create index idx_markers_report_id on public.markers (report_id);
