-- ============================================================================
-- Marketplace admin passphrase (audit SA-04). Before this, anyone who knew
-- the admin's profile id (readable from alumni_profiles) could approve and
-- reject listings and read the review queue. Now every admin function also
-- needs a secret passphrase that is checked in the database against a bcrypt
-- hash, so the profile id alone is no longer enough.
--
-- This is NOT real authentication: a passphrase is a shared secret sent by
-- the app, and the profile id is still unauthenticated for every other
-- feature. It only closes the "admin id is public" hole. Choose a long random
-- passphrase (16+ characters is enforced).
--
-- After applying, NO ONE is admin until you set a passphrase, from the SQL
-- editor (owner only, the API roles cannot run this):
--   select marketplace_set_admin_key('<admin profile uuid>', '<16+ char passphrase>');
--
-- Every refused attempt takes one second (pg_sleep), which limits online
-- guessing. Known trade-off: an attacker can hold connections that way.
--
-- NOT applied to any live project by whoever wrote it. Rollback:
-- supabase/rollback_security_hardening.sql
-- Idempotent: safe to re-run.
-- ============================================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

alter table marketplace_admins add column if not exists key_hash text;

create or replace function marketplace_set_admin_key(p_profile uuid, p_key text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if char_length(coalesce(p_key, '')) < 16 then
    raise exception 'admin passphrase must be at least 16 characters';
  end if;
  update marketplace_admins
  set key_hash = crypt(p_key, gen_salt('bf', 10))
  where profile_id = p_profile;
  if not found then
    raise exception 'that profile is not in marketplace_admins';
  end if;
end;
$$;
revoke execute on function marketplace_set_admin_key(uuid, text) from public, anon, authenticated;

-- Internal check used by the admin functions below. Not callable by the API.
create or replace function marketplace_admin_authorized(p_admin uuid, p_key text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  h text;
begin
  select key_hash into h from marketplace_admins where profile_id = p_admin;
  if h is not null and p_key is not null and crypt(p_key, h) = h then
    return true;
  end if;
  perform pg_sleep(1); -- every refusal costs a second
  return false;
end;
$$;
revoke execute on function marketplace_admin_authorized(uuid, text) from public, anon, authenticated;

-- The old id-only signatures must go, or they would stay callable.
drop function if exists marketplace_admin_pending(uuid);
drop function if exists marketplace_review_listing(uuid, uuid, text, text);
drop function if exists marketplace_report_counts(uuid);

create or replace function marketplace_admin_pending(p_admin uuid, p_key text default null)
returns setof marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
begin
  if not marketplace_admin_authorized(p_admin, p_key) then raise exception 'not_admin'; end if;
  return query
    select * from marketplace_listings
    where status = 'pending'
    order by created_at asc;
end;
$$;

create or replace function marketplace_review_listing(
  p_admin uuid,
  p_listing uuid,
  p_decision text,
  p_reason text default null,
  p_key text default null
)
returns marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v marketplace_listings;
begin
  if not marketplace_admin_authorized(p_admin, p_key) then raise exception 'not_admin'; end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception 'invalid_decision';
  end if;
  if p_decision = 'rejected' and nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'reason_required';
  end if;

  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if v.status <> 'pending' then raise exception 'invalid_state'; end if;

  update marketplace_listings set
    status = p_decision,
    rejected_reason = case when p_decision = 'rejected' then btrim(p_reason) else null end,
    approved_at = case when p_decision = 'approved' then now() else null end,
    reviewed_by = p_admin,
    reviewed_at = now(),
    updated_at = now()
  where id = p_listing
  returning * into v;

  return v;
end;
$$;

create or replace function marketplace_report_counts(p_admin uuid, p_key text default null)
returns table (listing_id uuid, report_count bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not marketplace_admin_authorized(p_admin, p_key) then raise exception 'not_admin'; end if;
  return query
    select r.listing_id, count(*)::bigint
    from marketplace_reports r
    group by r.listing_id
    order by count(*) desc;
end;
$$;

revoke execute on function marketplace_admin_pending(uuid, text) from public;
revoke execute on function marketplace_review_listing(uuid, uuid, text, text, text) from public;
revoke execute on function marketplace_report_counts(uuid, text) from public;
grant execute on function marketplace_admin_pending(uuid, text) to anon, authenticated;
grant execute on function marketplace_review_listing(uuid, uuid, text, text, text) to anon, authenticated;
grant execute on function marketplace_report_counts(uuid, text) to anon, authenticated;
