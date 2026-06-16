-- =============================================================================
-- Row Level Security — special category health data (UK GDPR Art. 9, PRD 6).
-- Every table has RLS enabled. Default-deny: a user can reach ONLY their own
-- data. The service_role key (server side) bypasses RLS for trusted backend
-- operations (audit writes, retention purges, AI persistence).
-- =============================================================================

alter table public.profiles        enable row level security;
alter table public.reports         enable row level security;
alter table public.markers         enable row level security;
alter table public.ai_explanations enable row level security;
alter table public.ai_summaries    enable row level security;
alter table public.consent_log     enable row level security;
alter table public.audit_event     enable row level security;

-- ---------------------------------------------------------------------------
-- profiles: a user sees and edits only their own row. Inserts are handled by
-- the handle_new_user() trigger (security definer); no client insert/delete.
-- ---------------------------------------------------------------------------
create policy "profiles_select_own" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- reports: full CRUD limited to the owner.
-- ---------------------------------------------------------------------------
create policy "reports_select_own" on public.reports
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy "reports_insert_own" on public.reports
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy "reports_update_own" on public.reports
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "reports_delete_own" on public.reports
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- markers: access derived from owning report.
-- ---------------------------------------------------------------------------
create policy "markers_select_own" on public.markers
  for select to authenticated
  using (exists (
    select 1 from public.reports r
    where r.id = markers.report_id and r.user_id = (select auth.uid())
  ));

create policy "markers_insert_own" on public.markers
  for insert to authenticated
  with check (exists (
    select 1 from public.reports r
    where r.id = markers.report_id and r.user_id = (select auth.uid())
  ));

create policy "markers_update_own" on public.markers
  for update to authenticated
  using (exists (
    select 1 from public.reports r
    where r.id = markers.report_id and r.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.reports r
    where r.id = markers.report_id and r.user_id = (select auth.uid())
  ));

create policy "markers_delete_own" on public.markers
  for delete to authenticated
  using (exists (
    select 1 from public.reports r
    where r.id = markers.report_id and r.user_id = (select auth.uid())
  ));

-- ---------------------------------------------------------------------------
-- ai_explanations: access derived from marker -> report owner.
-- ---------------------------------------------------------------------------
create policy "ai_explanations_select_own" on public.ai_explanations
  for select to authenticated
  using (exists (
    select 1 from public.markers m
    join public.reports r on r.id = m.report_id
    where m.id = ai_explanations.marker_id and r.user_id = (select auth.uid())
  ));

create policy "ai_explanations_insert_own" on public.ai_explanations
  for insert to authenticated
  with check (exists (
    select 1 from public.markers m
    join public.reports r on r.id = m.report_id
    where m.id = ai_explanations.marker_id and r.user_id = (select auth.uid())
  ));

create policy "ai_explanations_delete_own" on public.ai_explanations
  for delete to authenticated
  using (exists (
    select 1 from public.markers m
    join public.reports r on r.id = m.report_id
    where m.id = ai_explanations.marker_id and r.user_id = (select auth.uid())
  ));

-- ---------------------------------------------------------------------------
-- ai_summaries: access derived from owning report.
-- ---------------------------------------------------------------------------
create policy "ai_summaries_select_own" on public.ai_summaries
  for select to authenticated
  using (exists (
    select 1 from public.reports r
    where r.id = ai_summaries.report_id and r.user_id = (select auth.uid())
  ));

create policy "ai_summaries_insert_own" on public.ai_summaries
  for insert to authenticated
  with check (exists (
    select 1 from public.reports r
    where r.id = ai_summaries.report_id and r.user_id = (select auth.uid())
  ));

create policy "ai_summaries_delete_own" on public.ai_summaries
  for delete to authenticated
  using (exists (
    select 1 from public.reports r
    where r.id = ai_summaries.report_id and r.user_id = (select auth.uid())
  ));

-- ---------------------------------------------------------------------------
-- consent_log: a user may record (insert) and read their own consent history.
-- UPDATE/DELETE are blocked for everyone by triggers (immutable, append-only).
-- ---------------------------------------------------------------------------
create policy "consent_log_select_own" on public.consent_log
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy "consent_log_insert_own" on public.consent_log
  for insert to authenticated
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- audit_event: "not user-accessible" (PRD 6.2). RLS is enabled with NO policies
-- for authenticated/anon, so all client access is denied. Only service_role
-- (which bypasses RLS) may read or write it.
-- ---------------------------------------------------------------------------
