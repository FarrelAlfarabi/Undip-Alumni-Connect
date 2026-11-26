-- "Lamaran saya": the jobs I applied to, newest first. Applications are
-- already stored per member (job_applications.applicant_id). Direct table
-- reads are closed, so this function returns only the caller's own rows.
-- Jobs that were deleted take their applications with them (job_post_delete),
-- so they simply do not appear. Idempotent.
-- Rollback: supabase/rollback_my_job_applications.sql

create or replace function my_job_applications(p_applicant uuid)
returns table (application_id uuid, applied_at timestamptz, job jsonb)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_applicant);
  return query
    select a.id,
           a.created_at,
           to_jsonb(j) || jsonb_build_object(
             'poster', jsonb_build_object('name', p.name))
      from job_applications a
      join job_posts j on j.id = a.job_post_id
      left join alumni_profiles p on p.id = j.posted_by
     where a.applicant_id = p_applicant
     order by a.created_at desc;
end;
$$;

revoke execute on function my_job_applications(uuid) from public;
grant execute on function my_job_applications(uuid) to anon, authenticated;
