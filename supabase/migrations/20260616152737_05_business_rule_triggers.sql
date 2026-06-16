-- Enforce PRD 4.3: "Authenticated users may save up to 12 reports."
-- Counts only active (non-soft-deleted) reports per user.
create or replace function public.enforce_report_limit()
  returns trigger
  language plpgsql
as $$
declare
  active_count integer;
begin
  select count(*) into active_count
  from public.reports
  where user_id = new.user_id
    and deleted_at is null;

  if active_count >= 12 then
    raise exception 'Report limit reached: a user may save at most 12 reports (PRD 4.3). Delete an existing report first.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger trg_reports_enforce_limit
  before insert on public.reports
  for each row execute function public.enforce_report_limit();

-- Auto-provision a profiles row when a new auth user signs up, so app data has
-- a stable user record immediately (consent fields stay null until the gate is
-- accepted, PRD 4.4).
create or replace function public.handle_new_user()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
