-- ============================================================================
-- Simulated email notifications for job applications (18 Sep 2026).
--
-- Real email needs a transactional email provider (Resend etc.) with its
-- own account/API key/domain setup — a real external decision, not
-- something to wire silently. Until that's in place, this table records
-- exactly what email WOULD be sent (recipient, subject, body) whenever
-- someone applies to a job, so the "poster gets emailed" behavior is
-- demonstrable and inspectable in-app rather than invisible. Swapping in
-- a real provider later means calling out to it with these same fields —
-- no rework of the trigger's content logic.
-- ============================================================================

create table if not exists email_log (
  id uuid primary key default gen_random_uuid(),
  recipient_email text not null,
  subject text not null,
  body text not null,
  job_post_id uuid references job_posts (id),
  created_at timestamptz not null default now()
);

create index if not exists idx_email_log_recipient_email on email_log (recipient_email);
create index if not exists idx_email_log_job_post_id on email_log (job_post_id);

-- ----------------------------------------------------------------------------
-- RLS — same guardrail-not-access-control pattern as the rest of the
-- schema. Read/insert open, no update/delete (a log entry is never
-- edited once written).
-- ----------------------------------------------------------------------------
alter table email_log enable row level security;

create policy "email_log_select" on email_log for select using (true);
create policy "email_log_insert" on email_log for insert with check (true);

-- ----------------------------------------------------------------------------
-- Extend notify_poster_on_application (20260918100000_add_notifications.sql)
-- to also write the simulated email alongside the in-app notification, in
-- the same trigger firing so both channels are always in sync.
-- ----------------------------------------------------------------------------
create or replace function notify_poster_on_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job job_posts%rowtype;
  v_poster_email text;
  v_applicant_name text;
begin
  select * into v_job from job_posts where id = new.job_post_id;
  if v_job.id is null or v_job.notify_on_apply is false then
    return new;
  end if;

  v_applicant_name := coalesce(nullif(new.full_name, ''), 'Someone');

  insert into notifications (recipient_id, job_post_id, title, body)
  values (
    v_job.posted_by,
    v_job.id,
    'New application: ' || v_job.title,
    v_applicant_name || ' applied to your "' || v_job.title || '" posting.'
  );

  select email into v_poster_email from alumni_profiles where id = v_job.posted_by;

  if v_poster_email is not null then
    insert into email_log (recipient_email, subject, body, job_post_id)
    values (
      v_poster_email,
      'New application for ' || v_job.title,
      v_applicant_name || ' just applied to your job posting "' || v_job.title ||
        '" at ' || v_job.company || '. Open UNDIP Alumni Connect to review the application.',
      v_job.id
    );
  end if;

  return new;
end;
$$;

revoke execute on function notify_poster_on_application() from public, anon, authenticated;
