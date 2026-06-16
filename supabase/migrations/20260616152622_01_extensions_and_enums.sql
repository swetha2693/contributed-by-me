-- Lab Results Explainer — foundational extensions and enumerated types
-- See PRD v1.0 Section 6 (Data Model)

-- moddatetime: auto-maintain updated_at columns
create extension if not exists moddatetime schema extensions;

-- Source of an uploaded report (PRD 4.1.1). Image/OCR is v1.1, intentionally omitted.
create type public.report_source_type as enum ('pdf', 'text');

-- Lab flag carried on each parsed marker row (PRD 6.1, 4.1.2)
create type public.lab_flag as enum ('H', 'L', 'normal');

-- Audit event categories (PRD 6.1 audit_event: "Covers report upload, marker
-- parse, AI call, export, deletion, consent")
create type public.audit_event_type as enum (
  'report_upload',
  'marker_parse',
  'ai_call',
  'export',
  'deletion',
  'consent'
);

-- Entities an audit event can reference (PRD 6.1 audit_event.entity_type)
create type public.audit_entity_type as enum (
  'user',
  'report',
  'marker',
  'ai_explanation',
  'ai_summary',
  'consent_log'
);

-- Which AI feature produced an output (PRD 5.1 / 5.2)
create type public.ai_feature_type as enum ('marker_explainer', 'report_summariser');
