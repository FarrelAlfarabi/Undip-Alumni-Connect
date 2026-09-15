-- ============================================================================
-- Job application feature (added 17 Sep 2026, per Master Plan §3.4 item 7).
--
-- Applying to a job is now a real application (form + CV upload + other
-- profile links), not just seeing the poster's contact info. The poster
-- can opt in, per job post, to being notified when someone applies
-- (notify_on_apply) — in this demo build that's an in-app "N new
-- applicants" indicator on the job's own detail screen, not a real
-- push/email notification (same demo-scope limitation as everywhere else
-- in this project: no real push notifications, see PROJECT_NOTES.md).
-- ============================================================================

alter table job_posts add column if not exists notify_on_apply boolean not null default true;

create table if not exists job_applications (
  id uuid primary key default gen_random_uuid(),
  job_post_id uuid not null references job_posts (id),
  applicant_id uuid not null references alumni_profiles (id),
  full_name text not null,
  email text not null,
  phone text,
  linkedin_url text,
  portfolio_url text,
  cover_note text,
  cv_path text,
  created_at timestamptz not null default now()
);

create index if not exists idx_job_applications_job_post_id on job_applications (job_post_id);

-- ----------------------------------------------------------------------------
-- RLS — same vandalism-guardrail pattern as the rest of the schema (see
-- 20260915120000_add_basic_rls.sql): read + insert open (the app needs
-- both), no update/delete since the app never edits or removes an
-- application once submitted. This does NOT restrict who can read whose
-- applications -- there is no real login in this app (see that migration's
-- header comment), so that limitation applies here too.
-- ----------------------------------------------------------------------------
alter table job_applications enable row level security;

create policy "job_applications_select" on job_applications
  for select using (true);

create policy "job_applications_insert" on job_applications
  for insert with check (true);

-- ----------------------------------------------------------------------------
-- Storage bucket for uploaded CVs. Public read, same as every other table
-- in this demo (see the RLS migrations' repeated note: no real per-user
-- access control is possible without real auth). Do not treat this as a
-- private file store.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('cvs', 'cvs', true)
on conflict (id) do nothing;

create policy "cvs_public_read" on storage.objects
  for select using (bucket_id = 'cvs');

create policy "cvs_public_upload" on storage.objects
  for insert with check (bucket_id = 'cvs');
