-- Undo 20261019100000_contact_request_limits.sql. Safe to run twice.
-- Back to the trigger from 20261003140000 (blocks, 5 per day, 30 day
-- cool-down, one open per pair). No data is touched.
create or replace function contact_requests_enforce()
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

  if new.requester_id = new.target_id then raise exception 'cannot_request_self'; end if;

  if exists (
    select 1 from user_blocks
    where blocker_id = new.target_id and blocked_id = new.requester_id
  ) then
    raise exception 'blocked';
  end if;

  if exists (
    select 1 from contact_requests
    where requester_id = new.requester_id and target_id = new.target_id and status = 'pending'
  ) then
    raise exception 'request_already_open';
  end if;

  if exists (
    select 1 from contact_requests
    where requester_id = new.requester_id and target_id = new.target_id
      and status = 'rejected' and responded_at > now() - interval '30 days'
  ) then
    raise exception 'cooldown_active';
  end if;

  v_day_start := date_trunc('day', now() at time zone 'Asia/Jakarta') at time zone 'Asia/Jakarta';
  if (select count(*) from contact_requests
      where requester_id = new.requester_id and created_at >= v_day_start) >= 5 then
    raise exception 'daily_limit_reached';
  end if;

  return new;
end;
$$;
