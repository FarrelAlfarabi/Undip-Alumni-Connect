-- Job posts had no posting limit (spam risk). Now one person can post at most
-- 5 job posts per day (Jakarta time) and keep at most 20 open ones. Only the
-- app roles (anon, authenticated) are limited; the dashboard is not.
-- The daily count uses a small log, so deleting a post does not free a slot.
-- Idempotent. Rollback: supabase/rollback_job_posting_limit.sql
create table if not exists job_post_log (
  posted_by uuid not null,
  created_at timestamptz not null default now()
);
create index if not exists job_post_log_idx on job_post_log (posted_by, created_at);
alter table job_post_log enable row level security;
revoke all on job_post_log from anon, authenticated;

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
  if (select count(*) from job_post_log
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

-- Every new post is logged, whoever inserts it (app or dashboard).
create or replace function job_posts_log_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.posted_by is not null then
    insert into job_post_log (posted_by) values (new.posted_by);
  end if;
  return new;
end;
$$;
revoke execute on function job_posts_log_insert() from public, anon, authenticated;
drop trigger if exists job_posts_log_insert_trigger on job_posts;
create trigger job_posts_log_insert_trigger
  after insert on job_posts
  for each row execute function job_posts_log_insert();
