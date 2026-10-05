-- ============================================================================
-- Request to contact (closed beta, Stage 6B). Replaces chat.
--
-- A verified alumnus asks another verified alumnus to share contact details.
-- The target accepts by TYPING what to share (email, phone, WhatsApp, any
-- text, max 200) or rejects. The requester sees the status, and the shared
-- text only after accept. No in-app messaging.
--
-- Rules, enforced in the database:
--   * one open (pending) request per requester and target
--   * at most 5 new requests per requester per day (Jakarta day)
--   * after a rejection, the same requester cannot ask the same person
--     again for 30 days
--   * message max 200 characters, optional, plain text
--
-- shared_contact NEVER comes back from a list. The app has no direct table
-- access at all. It is released only by contact_request_shared_contact(),
-- which checks status = accepted and the requester id.
--
-- HONEST LIMIT: the app has no real login. The ids passed to these functions
-- are NOT authenticated, so anyone who knows a requester's profile id can
-- ask for their accepted contact. This is a speed bump, not security.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_contact_requests.sql
-- ============================================================================

create table if not exists contact_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references alumni_profiles (id),
  target_id uuid not null references alumni_profiles (id),
  message text check (message is null or char_length(message) <= 200),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  shared_contact text check (shared_contact is null or char_length(shared_contact) <= 200),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint contact_requests_not_self check (requester_id <> target_id),
  constraint contact_requests_accept_has_contact check (
    status <> 'accepted' or nullif(btrim(coalesce(shared_contact, '')), '') is not null
  )
);

create index if not exists idx_contact_requests_target on contact_requests (target_id, status);
create index if not exists idx_contact_requests_requester on contact_requests (requester_id, created_at);
create unique index if not exists contact_requests_one_open
  on contact_requests (requester_id, target_id) where status = 'pending';

alter table contact_requests enable row level security;
revoke all on contact_requests from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Insert guard (also covers any direct insert by the app roles). The
-- dashboard (role none / postgres / service_role) is not restricted.
-- ---------------------------------------------------------------------------
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
revoke execute on function contact_requests_enforce() from public, anon, authenticated;

drop trigger if exists contact_requests_enforce_trigger on contact_requests;
create trigger contact_requests_enforce_trigger
  before insert on contact_requests
  for each row execute function contact_requests_enforce();

-- ---------------------------------------------------------------------------
-- Functions the app calls
-- ---------------------------------------------------------------------------
create or replace function contact_request_send(p_requester uuid, p_target uuid, p_message text)
returns table (id uuid, status text, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_msg text := nullif(btrim(coalesce(p_message, '')), '');
  v contact_requests;
begin
  if not business_is_verified(p_requester) or not business_is_verified(p_target) then
    raise exception 'not_verified';
  end if;
  if char_length(coalesce(v_msg, '')) > 200 then raise exception 'message_too_long'; end if;

  insert into contact_requests (requester_id, target_id, message)
  values (p_requester, p_target, v_msg)
  returning * into v;

  return query select v.id, v.status, v.created_at;
end;
$$;

-- Requests sent TO this person. No shared_contact column.
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
  where r.target_id = p_target
  order by (r.status = 'pending') desc, r.created_at desc;
$$;

-- Requests this person SENT. No shared_contact column, and a rejection
-- carries no text.
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
  where r.requester_id = p_requester
  order by r.created_at desc;
$$;

-- For the badge on Home: requests waiting for an answer.
create or replace function contact_requests_pending_count(p_target uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer from contact_requests where target_id = p_target and status = 'pending';
$$;

create or replace function contact_request_respond(
  p_target uuid,
  p_request uuid,
  p_accept boolean,
  p_shared text
)
returns table (id uuid, status text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v contact_requests;
  v_shared text := nullif(btrim(coalesce(p_shared, '')), '');
begin
  select * into v from contact_requests where contact_requests.id = p_request for update;
  if not found then raise exception 'not_found'; end if;
  if v.target_id <> p_target then raise exception 'not_target'; end if;
  if v.status <> 'pending' then raise exception 'invalid_state'; end if;

  if p_accept then
    if v_shared is null then raise exception 'shared_required'; end if;
    if char_length(v_shared) > 200 then raise exception 'shared_too_long'; end if;
    update contact_requests set status = 'accepted', shared_contact = v_shared, responded_at = now()
      where contact_requests.id = p_request;
  else
    update contact_requests set status = 'rejected', shared_contact = null, responded_at = now()
      where contact_requests.id = p_request;
  end if;

  return query select r.id, r.status from contact_requests r where r.id = p_request;
end;
$$;

-- The ONLY way to read shared_contact: accepted, and the caller is the requester.
create or replace function contact_request_shared_contact(p_requester uuid, p_request uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v contact_requests;
begin
  select * into v from contact_requests where id = p_request;
  if not found then raise exception 'not_found'; end if;
  if v.requester_id <> p_requester then raise exception 'not_requester'; end if;
  if v.status <> 'accepted' then raise exception 'not_accepted'; end if;
  return v.shared_contact;
end;
$$;

revoke execute on function contact_request_send(uuid, uuid, text) from public;
revoke execute on function contact_requests_incoming(uuid) from public;
revoke execute on function contact_requests_outgoing(uuid) from public;
revoke execute on function contact_requests_pending_count(uuid) from public;
revoke execute on function contact_request_respond(uuid, uuid, boolean, text) from public;
revoke execute on function contact_request_shared_contact(uuid, uuid) from public;
grant execute on function contact_request_send(uuid, uuid, text) to anon, authenticated;
grant execute on function contact_requests_incoming(uuid) to anon, authenticated;
grant execute on function contact_requests_outgoing(uuid) to anon, authenticated;
grant execute on function contact_requests_pending_count(uuid) to anon, authenticated;
grant execute on function contact_request_respond(uuid, uuid, boolean, text) to anon, authenticated;
grant execute on function contact_request_shared_contact(uuid, uuid) to anon, authenticated;
