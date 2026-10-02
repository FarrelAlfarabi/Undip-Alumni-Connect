-- ============================================================================
-- Application status (2 Oct 2026). Applicants can now see where an
-- application stands, and the job poster can move it along from the
-- applicant list: pending -> reviewed -> accepted / rejected.
--
-- Existing applications become 'pending'. The app only ever updates the
-- status column, so that is the only column API roles may update.
--
-- Same demo-scope caveat as the rest of this schema: the app has no real
-- per-user session, so the update policy can't restrict WHO changes a
-- status (see 20260915120000_add_basic_rls.sql). It is a guardrail, not
-- access control.
-- ============================================================================

alter table job_applications
  add column if not exists status text not null default 'pending';

alter table job_applications
  drop constraint if exists job_applications_status_check;
alter table job_applications
  add constraint job_applications_status_check
  check (status in ('pending', 'reviewed', 'accepted', 'rejected'));

create index if not exists idx_job_applications_applicant_id
  on job_applications (applicant_id);

revoke update on job_applications from anon, authenticated;
grant update (status) on job_applications to anon, authenticated;

drop policy if exists "job_applications_update" on job_applications;
create policy "job_applications_update" on job_applications
  for update using (true) with check (true);
