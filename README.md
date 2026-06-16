# Lab Results Explainer

Plain-language educational context for lab results — **not a diagnostic tool**.
Built from the PRD v1.0 (see `supabase/DATABASE_DESIGN.md` for the data model).

## Stack

- **Next.js 14** (App Router, TypeScript) — deployable to Vercel
- **Supabase** (PostgreSQL 17) — schema, Row Level Security, and retention jobs
  in `supabase/migrations/`

## Local development

```bash
npm install
cp .env.example .env.local   # values are already filled in for the Supabase project
npm run dev                  # http://localhost:3000
```

## Environment variables

| Variable | Where | Notes |
|----------|-------|-------|
| `NEXT_PUBLIC_SUPABASE_URL` | client | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | client | Publishable key; safe to expose (RLS-protected) |
| `SUPABASE_SERVICE_ROLE_KEY` | server only | For audit writes / retention; **never** expose |
| `ANTHROPIC_API_KEY` | server only | Marker Explainer & Report Summariser (PRD 5) |

## Deploying to Vercel

1. Import this repo into Vercel (framework auto-detected as **Next.js**).
2. Add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` under
   **Project → Settings → Environment Variables**.
3. Deploy. `npm run build` is the build command; Vercel handles the output.

## Database

The schema is applied to the Supabase project `lab explainer results`. See
`supabase/DATABASE_DESIGN.md` for the ERD and design rationale, and
`supabase/migrations/` for the SQL.
