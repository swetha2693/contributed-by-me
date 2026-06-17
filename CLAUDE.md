# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Lab Results Explainer** — plain-language educational context for lab results. Not a diagnostic tool. Built with Next.js 14 (App Router) + Supabase (PostgreSQL 17).

## Commands

```bash
npm install          # install dependencies
npm run dev          # dev server at http://localhost:3000
npm run build        # production build
npm run lint         # ESLint via next lint
```

No test runner is configured yet.

## Environment variables

Copy `.env.example` to `.env.local` before running locally (values are pre-filled for the Supabase project `lab explainer results`, region `eu-central-1`).

| Variable | Side | Purpose |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | client | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | client | Publishable key; RLS-protected |
| `SUPABASE_SERVICE_ROLE_KEY` | server only | Audit writes and retention jobs; never expose |
| `ANTHROPIC_API_KEY` | server only | Marker Explainer and Report Summariser |

## Architecture

### Frontend
- `app/` — Next.js App Router pages and layouts (TypeScript, `"use client"` where needed)
- `lib/supabase.ts` — browser Supabase client using `@supabase/ssr` (`createBrowserClient`). A server-side client (using `SUPABASE_SERVICE_ROLE_KEY`) will be needed for audit writes and AI calls — it is not yet implemented.

### Database (`supabase/`)
Migrations in `supabase/migrations/` (applied in timestamp order). Schema design is documented in `supabase/DATABASE_DESIGN.md`.

Key tables:
- `profiles` — 1:1 with Supabase `auth.users`; stores salted email hash only (PII minimisation)
- `reports` — saved lab reports; `raw_text_encrypted` is AES-256 app-encrypted before insert
- `markers` — one row per extracted marker; `value_text` preserves raw strings like `< 5`; `needs_manual_review` is a generated column (`parser_confidence < 0.6`)
- `ai_explanations` / `ai_summaries` — ephemeral by default; persisted only on session save
- `consent_log` / `audit_event` — append-only compliance tables; immutability enforced by triggers

### Security model
- RLS is enabled on every table, default-deny. Users reach only their own rows via `auth.uid()`.
- `audit_event` has RLS with **no policies by design** — only the service role key can write to it.
- `consent_log` blocks UPDATE/DELETE via trigger; a GUC (`app.compliance_mode`) gates trusted retention routines.
- Retention is enforced by `pg_cron` daily jobs: reports purged at 24 months, audit events at 3 years, consent log at 7 years.

### Critical-value rule
`markers.is_critical` flags values >2× outside reference range. The app must suppress the AI explainer for these markers and direct users to NHS 111 (PRD 7.1/7.3).

### Application-layer rules (from DATABASE_DESIGN.md)
- Encrypt `raw_text_encrypted` with AES-256 **before** inserting into Supabase; the DB never sees plaintext.
- Use the service role key for all writes to `audit_event` and ephemeral AI outputs.
- Hash IP and device fingerprint before writing to `consent_log`.
- Soft-delete reports (set `deleted_at`); never hard-delete from the client.
- A trigger enforces a 12-report cap per user; surface a friendly error to the user on violation.
