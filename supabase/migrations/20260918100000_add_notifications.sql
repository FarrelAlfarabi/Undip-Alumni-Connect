-- ============================================================================
-- In-app notifications for job applications (18 Sep 2026, per Mas Gilang's
-- and the owner's feedback: posters need a real notification, not just an
-- applicant count they have to remember to check).
--
-- A row is inserted here automatically (via trigger, not app code, so it
-- can't be skipped by a client bug) whenever someone applies to a job
-- whose poster has notify_on_apply = true. Real-time delivery would need
-- a push service this demo doesn't have; this is the in-app half of the
-- notification — see PROJECT_NOTES.md for the email half.
-- ============================================================================

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references alumni_profiles (id),
  job_post_id uuid references job_posts (id),
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_recipient_id on notifications (recipient_id);
create index if not exists idx_notifications_job_post_id on notifications (job_post_id);

-- ----------------------------------------------------------------------------
-- RLS — same guardrail-not-access-control pattern as the rest of the
-- schema (see 20260915120000_add_basic_rls.sql): open read/insert/update,
-- since there's no real per-user auth session to restrict against. Update
-- is allowed so the app can mark a notification read.
-- ----------------------------------------------------------------------------
alter table notifications enable row level security;

create policy "notifications_select" on notifications for select using (true);
create policy "notifications_insert" on notifications for insert with check (true);
create policy "notifications_update" on notifications for update using (true);

-- ----------------------------------------------------------------------------
-- Trigger: whenever a job_applications row is inserted, notify that job's
-- poster (unless they turned notify_on_apply off for that posting).
-- SECURITY DEFINER so it can read job_posts and write notifications
-- regardless of which role performed the insert (anon, same as
-- everywhere else in this schema).
-- ----------------------------------------------------------------------------
create or replace function notify_poster_on_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job job_posts%rowtype;
begin
  select * into v_job from job_posts where id = new.job_post_id;

  if v_job.id is not null and v_job.notify_on_apply is not false then
    insert into notifications (recipient_id, job_post_id, title, body)
    values (
      v_job.posted_by,
      v_job.id,
      'New application: ' || v_job.title,
      coalesce(nullif(new.full_name, ''), 'Someone') || ' applied to your "' ||
        v_job.title || '" posting.'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists job_applications_notify_poster on job_applications;

create trigger job_applications_notify_poster
  after insert on job_applications
  for each row execute function notify_poster_on_application();

-- PostgREST auto-exposes every public-schema function as a callable RPC
-- endpoint, including trigger functions, which Postgres would refuse to
-- run outside trigger context anyway — but the linter flags it, and
-- there's no reason for anon/authenticated to be able to call it
-- directly, so revoke explicitly.
revoke execute on function notify_poster_on_application() from public, anon, authenticated;
