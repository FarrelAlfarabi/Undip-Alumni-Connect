-- ============================================================================
-- Contact request limits.
--
-- Already in place (20261003120000, 20261003140000): 5 new requests per day,
-- one open request per pair, 30 day cool-down after a rejection, blocks.
--
-- Added here:
--   * at most 10 open (pending) requests per requester at a time
--     -> error 'too_many_open'. Answering a request frees a slot.
--   * no new request to someone who already accepted you (you already have
--     their contact) -> error 'already_shared'.
--
-- Only the insert guard changes. No table or column changes. The dashboard
-- (role none / postgres / service_role) is still not restricted.
-- Idempotent. Not applied to any live project by whoever wrote it.
-- Rollback: supabase/rollback_contact_request_limits.sql
-- ============================================================================

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
    where requester_id = new.requester_id and target_id = new.target_id and status = 'accepted'
  ) then
    raise exception 'already_shared';
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

  if (select count(*) from contact_requests
      where requester_id = new.requester_id and status = 'pending') >= 10 then
    raise exception 'too_many_open';
  end if;

  return new;
end;
$$;
