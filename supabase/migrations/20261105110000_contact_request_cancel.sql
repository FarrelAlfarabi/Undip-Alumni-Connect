-- ============================================================================
-- Cancel a pending contact request, and withdraw a job application
-- (5 Nov 2026).
--
--   * contact_requests.status gets a fourth value, 'cancelled'. The sender
--     can cancel only while the request is pending. A cancelled request still
--     counts for the 5 per day limit (the row stays), is not an "open"
--     request, and starts no 30 day cool-down.
--   * contact_requests_incoming / _outgoing no longer list cancelled rows.
--   * job_application_withdraw(applicant, job): the applicant deletes their
--     own application.
--
-- Idempotent. Rollback: supabase/rollback_contact_request_cancel.sql
-- ============================================================================

do $$
declare
  c record;
begin
  for c in
    select conname from pg_constraint
     where conrelid = 'contact_requests'::regclass and contype = 'c'
       and pg_get_constraintdef(oid) like '%rejected%'
       and pg_get_constraintdef(oid) like '%status%'
  loop
    execute format('alter table contact_requests drop constraint %I', c.conname);
  end loop;
  alter table contact_requests add constraint contact_requests_status_check
    check (status in ('pending', 'accepted', 'rejected', 'cancelled'));
end $$;

create or replace function contact_requests_incoming(p_target uuid)
returns table (
  id uuid,
  requester_id uuid,
  requester_name text,
  message text,
  status text,
  created_at timestamptz,
  responded_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select r.id, r.requester_id, p.name, r.message, r.status, r.created_at, r.responded_at
  from contact_requests r
  join alumni_profiles p on p.id = r.requester_id
  where r.target_id = p_target and r.status <> 'cancelled'
  order by (r.status = 'pending') desc, r.created_at desc;
$$;

create or replace function contact_requests_outgoing(p_requester uuid)
returns table (
  id uuid,
  target_id uuid,
  target_name text,
  status text,
  created_at timestamptz,
  responded_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select r.id, r.target_id, p.name, r.status, r.created_at, r.responded_at
  from contact_requests r
  join alumni_profiles p on p.id = r.target_id
  where r.requester_id = p_requester and r.status <> 'cancelled'
  order by r.created_at desc;
$$;

create or replace function contact_request_cancel(p_requester uuid, p_request uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v contact_requests;
begin
  perform assert_caller(p_requester);
  select * into v from contact_requests where id = p_request for update;
  if not found then raise exception 'not_found'; end if;
  if v.requester_id <> p_requester then raise exception 'not_requester'; end if;
  if v.status <> 'pending' then raise exception 'invalid_state'; end if;
  update contact_requests set status = 'cancelled', responded_at = now()
   where id = p_request;
end;
$$;

create or replace function job_application_withdraw(p_applicant uuid, p_job uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_applicant);
  delete from job_applications
   where applicant_id = p_applicant and job_post_id = p_job;
end;
$$;

revoke execute on function contact_requests_incoming(uuid) from public;
revoke execute on function contact_requests_outgoing(uuid) from public;
revoke execute on function contact_request_cancel(uuid, uuid) from public;
revoke execute on function job_application_withdraw(uuid, uuid) from public;
grant execute on function contact_requests_incoming(uuid) to anon, authenticated;
grant execute on function contact_requests_outgoing(uuid) to anon, authenticated;
grant execute on function contact_request_cancel(uuid, uuid) to anon, authenticated;
grant execute on function job_application_withdraw(uuid, uuid) to anon, authenticated;
