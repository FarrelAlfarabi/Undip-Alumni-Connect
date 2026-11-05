-- Job applications were readable by anyone (name, email, phone, cover note).
-- Now only the poster of the job can read them, through functions that check
-- who is asking. Direct table reads are closed. Applying (insert) still works
-- straight from the app. The CV storage bucket stays public-by-link as before
-- (files have unguessable timestamped names); making it private is a later,
-- separate change.
-- Idempotent. Rollback: supabase/rollback_job_applications_private.sql

drop policy if exists "job_applications_select" on job_applications;
revoke select on job_applications from anon, authenticated;

create or replace function job_applicants_list(p_poster uuid, p_job uuid)
returns setof job_applications
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_poster);
  if not exists (select 1 from job_posts j where j.id = p_job and j.posted_by = p_poster) then
    raise exception 'not_owner';
  end if;
  return query
    select * from job_applications a where a.job_post_id = p_job order by a.created_at desc;
end;
$$;

-- Applicant counts for the poster's own jobs (job id, count).
create or replace function job_applicant_counts(p_poster uuid)
returns table (job_post_id uuid, applicant_count bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_poster);
  return query
    select a.job_post_id, count(*)::bigint
      from job_applications a
      join job_posts j on j.id = a.job_post_id
     where j.posted_by = p_poster
     group by a.job_post_id;
end;
$$;

-- Did I already apply to this job?
create or replace function job_application_exists(p_applicant uuid, p_job uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_applicant);
  return exists (
    select 1 from job_applications a
     where a.applicant_id = p_applicant and a.job_post_id = p_job
  );
end;
$$;

revoke execute on function job_applicants_list(uuid, uuid) from public;
revoke execute on function job_applicant_counts(uuid) from public;
revoke execute on function job_application_exists(uuid, uuid) from public;
grant execute on function job_applicants_list(uuid, uuid) to anon, authenticated;
grant execute on function job_applicant_counts(uuid) to anon, authenticated;
grant execute on function job_application_exists(uuid, uuid) to anon, authenticated;
