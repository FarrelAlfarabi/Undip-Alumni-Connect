-- ============================================================================
-- One PIN per account (24 Nov 2026).
--
-- Before this, the 6-digit PIN lived only on the device (phone secure
-- storage, browser local storage), so a PIN made on the laptop did not open
-- the phone. Now the account has one PIN:
--
--   * member_pins: one row per profile with a bcrypt hash of the PIN
--     (pgcrypto, cost 8), the wrong-try count and the wait time. The PIN
--     itself is never stored. The table has no grants for anon or
--     authenticated and RLS on with no policies: only these functions (and
--     the dashboard) touch it.
--   * pin_status / pin_set / pin_check / pin_remove: only for the signed in
--     person (current_profile_id(), so a suspended member is refused too).
--     They take no profile id, so nobody can name someone else's account.
--   * Wrong tries count for the account on every device: from the 3rd wrong
--     try the next one waits 10 seconds, the 5th wrong try removes the PIN
--     (the person signs in again with an email code and makes a new one).
--     Same numbers as lib/lock/lock_config.dart.
--   * A wrong try older than 1 hour no longer counts (typos spread over
--     months never remove the PIN).
--   * Replacing an existing PIN needs the old PIN, or an email code sign in
--     in the last 15 minutes ("Lupa PIN" signs in again first). So a stolen
--     sign in cannot reset the wrong-try count by setting a new PIN.
--   * A removed profile takes its PIN row with it (on delete cascade).
--
-- Admins do not see or reset PINs: a member who forgets it taps "Lupa PIN",
-- signs in with an email code and makes a new PIN.
--
-- Idempotent. Rollback: supabase/rollback_account_pin.sql
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

create table if not exists member_pins (
  profile_id uuid primary key references alumni_profiles (id) on delete cascade,
  pin_hash text not null,
  failed int not null default 0 check (failed >= 0),
  wait_until timestamptz,
  last_wrong_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table member_pins add column if not exists last_wrong_at timestamptz;

alter table member_pins enable row level security;
revoke all on member_pins from public, anon, authenticated;

-- The signed in person, or an error. Never trusts an id from the app.
create or replace function pin_caller()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v uuid := current_profile_id();
begin
  if auth.uid() is null or v is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  return v;
end;
$$;

create or replace function pin_status()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return exists (select 1 from member_pins where profile_id = pin_caller());
end;
$$;

drop function if exists pin_set(text);
create or replace function pin_set(p_pin text, p_old text default null)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v uuid := pin_caller();
  r member_pins;
  v_signed_in timestamptz;
begin
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    raise exception 'invalid_pin';
  end if;
  select * into r from member_pins where profile_id = v for update;
  if found then
    select last_sign_in_at into v_signed_in from auth.users where id = auth.uid();
    if not (
      (p_old is not null and extensions.crypt(p_old, r.pin_hash) = r.pin_hash)
      or coalesce(v_signed_in > now() - interval '15 minutes', false)
    ) then
      raise exception 'old_pin_required';
    end if;
  end if;
  insert into member_pins (profile_id, pin_hash, failed, wait_until, last_wrong_at, updated_at)
  values (v, extensions.crypt(p_pin, extensions.gen_salt('bf', 8)), 0, null, null, now())
  on conflict (profile_id) do update
    set pin_hash = excluded.pin_hash,
        failed = 0,
        wait_until = null,
        last_wrong_at = null,
        updated_at = now();
end;
$$;

-- {"status": "ok" | "wrong" | "wait" | "locked" | "none",
--  "left": tries left (wrong), "wait_until": time (wrong from the 3rd, wait)}
create or replace function pin_check(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v uuid := pin_caller();
  r member_pins;
  n int;
  until timestamptz;
begin
  select * into r from member_pins where profile_id = v for update;
  if not found then
    return jsonb_build_object('status', 'none');
  end if;
  if r.wait_until is not null and r.wait_until > now() then
    return jsonb_build_object('status', 'wait', 'wait_until', r.wait_until);
  end if;
  if p_pin is not null and p_pin ~ '^[0-9]{6}$'
     and extensions.crypt(p_pin, r.pin_hash) = r.pin_hash then
    update member_pins set failed = 0, wait_until = null, last_wrong_at = null
     where profile_id = v;
    return jsonb_build_object('status', 'ok');
  end if;
  n := case
    when r.last_wrong_at is null or r.last_wrong_at < now() - interval '1 hour' then 1
    else r.failed + 1
  end;
  if n >= 5 then
    delete from member_pins where profile_id = v;
    return jsonb_build_object('status', 'locked');
  end if;
  if n >= 3 then
    until := now() + interval '10 seconds';
  end if;
  update member_pins set failed = n, wait_until = until, last_wrong_at = now()
   where profile_id = v;
  return jsonb_build_object('status', 'wrong', 'left', 5 - n, 'wait_until', until);
end;
$$;

create or replace function pin_remove()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from member_pins where profile_id = pin_caller();
end;
$$;

revoke execute on function pin_caller() from public, anon, authenticated;
revoke execute on function pin_status() from public, anon;
revoke execute on function pin_set(text, text) from public, anon;
revoke execute on function pin_check(text) from public, anon;
revoke execute on function pin_remove() from public, anon;
grant execute on function pin_status() to authenticated;
grant execute on function pin_set(text, text) to authenticated;
grant execute on function pin_check(text) to authenticated;
grant execute on function pin_remove() to authenticated;
