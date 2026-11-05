-- Job posts had no posting limit (spam risk). Now one person can post at most
-- 5 job posts per day (Jakarta time) and keep at most 20 open ones. Only the
-- app roles (anon, authenticated) are limited; the dashboard is not.
-- Idempotent. Rollback: supabase/rollback_job_posting_limit.sql
create or replace function job_posts_limit()
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
  if new.posted_by is null then return new; end if;
  v_day_start := date_trunc('day', now() at time zone 'Asia/Jakarta') at time zone 'Asia/Jakarta';
  if (select count(*) from job_posts
       where posted_by = new.posted_by and created_at >= v_day_start) >= 5 then
    raise exception 'job_daily_limit';
  end if;
  if (select count(*) from job_posts
       where posted_by = new.posted_by and closed_at is null and hidden_at is null) >= 20 then
    raise exception 'job_open_limit';
  end if;
  return new;
end;
$$;
revoke execute on function job_posts_limit() from public, anon, authenticated;

drop trigger if exists job_posts_limit_trigger on job_posts;
create trigger job_posts_limit_trigger
  before insert on job_posts
  for each row execute function job_posts_limit();
