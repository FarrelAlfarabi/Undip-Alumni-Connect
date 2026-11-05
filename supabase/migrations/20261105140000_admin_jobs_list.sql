-- Admin Jobs list: lets an admin find any job post and take it down (hide)
-- or put it back, without waiting for a report. Hiding and restoring use the
-- existing admin_reports_decide('job', ...), which also tells the poster
-- (job_posts_notify_hidden trigger). Read-only function, idempotent.
create or replace function admin_jobs_list(p_admin uuid, p_search text default null)
returns table (
  id uuid,
  title text,
  company text,
  poster_name text,
  created_at timestamptz,
  hidden_at timestamptz,
  hidden_reason text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_q text := nullif(btrim(coalesce(p_search, '')), '');
begin
  perform app_admin_assert(p_admin);
  return query
    select j.id, j.title, j.company, p.name, j.created_at, j.hidden_at, j.hidden_reason
      from job_posts j
      left join alumni_profiles p on p.id = j.posted_by
     where v_q is null
        or j.title ilike '%' || v_q || '%'
        or j.company ilike '%' || v_q || '%'
        or p.name ilike '%' || v_q || '%'
     order by (j.hidden_at is null), j.created_at desc
     limit 100;
end;
$$;
revoke execute on function admin_jobs_list(uuid, text) from public;
grant execute on function admin_jobs_list(uuid, text) to anon, authenticated;
