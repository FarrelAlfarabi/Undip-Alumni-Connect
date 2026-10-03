-- ============================================================================
-- Feedback on errors (closed beta, Stage 6F).
--
-- Every error screen and failed form in the app offers "Send feedback". The
-- app INSERTS a row here and can do nothing else: no read, no update, no
-- delete (no "returning" either). Admins read the rows and change their
-- status only through admin_feedback_* functions (they check app_admins).
-- You can always see and edit everything in the Supabase dashboard.
--
--   * profile_id is nullable, because errors can happen before verification.
--   * Daily limit: 10 per profile per day (Jakarta day), enforced by a trigger.
--   * A row WITHOUT a profile id has only the length limits. So anyone with
--     the anon key can still fill this table with junk. Accepted for the
--     closed beta (see docs/DECISIONS.md).
--   * No notification is created for feedback.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_feedback_reports.sql
-- ============================================================================

create table if not exists feedback_reports (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references alumni_profiles (id),
  message text check (message is null or char_length(message) <= 500),
  error_text text check (error_text is null or char_length(error_text) <= 300),
  screen text check (screen is null or char_length(screen) <= 60),
  app_version text check (app_version is null or char_length(app_version) <= 30),
  build_number text check (build_number is null or char_length(build_number) <= 20),
  platform text check (platform is null or char_length(platform) <= 30),
  status text not null default 'new' check (status in ('new', 'seen', 'done')),
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists idx_feedback_reports_created on feedback_reports (created_at desc);
create index if not exists idx_feedback_reports_profile on feedback_reports (profile_id, created_at);

alter table feedback_reports enable row level security;
revoke all on feedback_reports from public, anon, authenticated;
grant insert on feedback_reports to anon, authenticated;

drop policy if exists "feedback_reports_insert" on feedback_reports;
create policy "feedback_reports_insert" on feedback_reports
  for insert to anon, authenticated
  with check (status = 'new');

create or replace function feedback_reports_enforce()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day_start timestamptz;
begin
  if coalesce(current_setting('role', true), '') not in ('anon', 'authenticated') then
    return new;
  end if;
  -- The app cannot back-date a row to dodge the daily limit.
  new.created_at := clock_timestamp();
  if new.profile_id is not null then
    v_day_start := date_trunc('day', now() at time zone 'Asia/Jakarta') at time zone 'Asia/Jakarta';
    if (select count(*) from feedback_reports
        where profile_id = new.profile_id and created_at >= v_day_start) >= 10 then
      raise exception 'feedback_daily_limit';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function feedback_reports_enforce() from public, anon, authenticated;

drop trigger if exists feedback_reports_enforce_trigger on feedback_reports;
create trigger feedback_reports_enforce_trigger
  before insert on feedback_reports
  for each row execute function feedback_reports_enforce();

-- ------------------------------------------------------------ admin side ---
create or replace function admin_feedback_list(p_admin uuid)
returns table (
  id uuid,
  profile_name text,
  message text,
  error_text text,
  screen text,
  app_version text,
  build_number text,
  platform text,
  status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select f.id, p.name, f.message, f.error_text, f.screen, f.app_version,
           f.build_number, f.platform, f.status, f.created_at
    from feedback_reports f
    left join alumni_profiles p on p.id = f.profile_id
    order by f.created_at desc, f.id desc;
end;
$$;

create or replace function admin_feedback_new_count(p_admin uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return (select count(*)::integer from feedback_reports where status = 'new');
end;
$$;

create or replace function admin_feedback_set_status(p_admin uuid, p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  if p_status is null or p_status not in ('new', 'seen', 'done') then
    raise exception 'invalid_status';
  end if;
  update feedback_reports set status = p_status where id = p_id;
  if not found then raise exception 'not_found'; end if;
end;
$$;

revoke execute on function admin_feedback_list(uuid) from public;
revoke execute on function admin_feedback_new_count(uuid) from public;
revoke execute on function admin_feedback_set_status(uuid, uuid, text) from public;
grant execute on function admin_feedback_list(uuid) to anon, authenticated;
grant execute on function admin_feedback_new_count(uuid) to anon, authenticated;
grant execute on function admin_feedback_set_status(uuid, uuid, text) to anon, authenticated;
