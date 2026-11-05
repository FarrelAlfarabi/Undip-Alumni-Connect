-- Undo 20261105110000_contact_request_cancel.sql. Safe to run twice.
-- Cancelled requests become 'rejected' first so the old constraint holds.
update contact_requests set status = 'rejected' where status = 'cancelled';
alter table contact_requests drop constraint if exists contact_requests_status_check;
alter table contact_requests add constraint contact_requests_status_check
  check (status in ('pending', 'accepted', 'rejected'));
drop function if exists contact_request_cancel(uuid, uuid);
drop function if exists job_application_withdraw(uuid, uuid);
create or replace function contact_requests_incoming(p_target uuid)
returns table (id uuid, requester_id uuid, requester_name text, message text,
  status text, created_at timestamptz, responded_at timestamptz)
language sql stable security definer set search_path = public
as $$
  select r.id, r.requester_id, p.name, r.message, r.status, r.created_at, r.responded_at
  from contact_requests r join alumni_profiles p on p.id = r.requester_id
  where r.target_id = p_target
  order by (r.status = 'pending') desc, r.created_at desc;
$$;
create or replace function contact_requests_outgoing(p_requester uuid)
returns table (id uuid, target_id uuid, target_name text, status text,
  created_at timestamptz, responded_at timestamptz)
language sql stable security definer set search_path = public
as $$
  select r.id, r.target_id, p.name, r.status, r.created_at, r.responded_at
  from contact_requests r join alumni_profiles p on p.id = r.target_id
  where r.requester_id = p_requester
  order by r.created_at desc;
$$;
