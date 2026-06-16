-- =============================================================================
-- ai_explanations  (PRD 6.1 "ai_explanation" + 5.1 Marker Explainer)
-- One AI explanation per marker expansion. Ephemeral by default (in-memory);
-- persisted only if the user saves the session. response_json stores the full
-- structured output validated against the PRD 5.1.2 schema.
-- =============================================================================
create table public.ai_explanations (
  id                 uuid primary key default gen_random_uuid(),
  marker_id          uuid not null references public.markers (id) on delete cascade,
  model_version      text not null,                 -- Anthropic model id used (PRD 5: Anthropic Messages API)
  prompt_hash        text not null,                 -- hash of the exact prompt for reproducibility/audit
  response_json      jsonb not null,                -- full validated output (PRD 5.1.2 schema)
  schema_valid       boolean not null,              -- did output validate? false => fallback shown (PRD 5.1.3)
  confidence         numeric check (confidence >= 0 and confidence <= 1), -- model self-reported; <0.7 -> review banner (PRD 5.1.3)
  flagged_for_review boolean not null default false,-- set by diagnostic-language / low-confidence checks (PRD 5.1.4)
  generated_at       timestamptz not null default now()
);

comment on table public.ai_explanations is 'Marker Explainer output (PRD 5.1). Persisted only when the user saves the session; otherwise ephemeral.';
comment on column public.ai_explanations.schema_valid is 'False indicates JSON schema validation failed (P1 incident) and a fallback message was shown (PRD 5.1.3/5.1.4).';

create index idx_ai_explanations_marker_id on public.ai_explanations (marker_id);
create index idx_ai_explanations_flagged on public.ai_explanations (flagged_for_review) where flagged_for_review = true;

-- =============================================================================
-- ai_summaries  (PRD 6.1 "ai_summary" + 5.2 Report Summariser & Question Gen)
-- One whole-report summary + question list per generation. Same persistence
-- rules as ai_explanations. response_json holds both summary and questions
-- (PRD 5.2.2 schema).
-- =============================================================================
create table public.ai_summaries (
  id                 uuid primary key default gen_random_uuid(),
  report_id          uuid not null references public.reports (id) on delete cascade,
  model_version      text not null,
  prompt_hash        text not null,
  response_json      jsonb not null,                -- full validated output incl. summary + questions (PRD 5.2.2)
  schema_valid       boolean not null,
  confidence         numeric check (confidence >= 0 and confidence <= 1),
  flagged_for_review boolean not null default false,
  generated_at       timestamptz not null default now()
);

comment on table public.ai_summaries is 'Report Summariser + Question Generator output (PRD 5.2). One model call returns both; persisted only when saved.';

create index idx_ai_summaries_report_id on public.ai_summaries (report_id);
create index idx_ai_summaries_flagged on public.ai_summaries (flagged_for_review) where flagged_for_review = true;
