-- Undo 20261105170000_job_applications_private.sql. Safe to run twice.
drop function if exists job_applicants_list(uuid, uuid);
drop function if exists job_applicant_counts(uuid);
drop function if exists job_application_exists(uuid, uuid);
grant select on job_applications to anon, authenticated;
drop policy if exists "job_applications_select" on job_applications;
create policy "job_applications_select" on job_applications for select using (true);
