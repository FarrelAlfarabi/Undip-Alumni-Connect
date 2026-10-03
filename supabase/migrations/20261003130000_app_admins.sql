-- ============================================================================
-- Admins without a passphrase (closed beta, Stage 6C).
--
-- Admins are rows in app_admins. YOU fill the table from the Supabase
-- dashboard (SQL editor or Table editor). The app roles cannot read, insert,
-- update or delete it. The app only asks one question: is_app_admin(profile).
--
-- Every admin action is a SECURITY DEFINER function that takes the caller's
-- profile id and checks app_admins. The old passphrase based functions are
-- redefined to check app_admins instead. The old passphrase now does
-- nothing: a profile with the right passphrase but no app_admins row is
-- refused, and an admin needs no passphrase. The stored passphrase data
-- (marketplace_admins.key_hash) is NOT deleted.
--
-- Business decisions (approve with a band, reject with a reason, suspend,
-- restore) change status and approved_band ONLY. unlimited_until stays
-- dashboard only.
--
-- HONEST LIMIT: the app has no real login. The admin id sent by the app is
-- NOT authenticated, so anyone who knows an admin's profile id can call these
-- functions. This is accepted ONLY for the closed beta. The real fix is
-- Supabase Auth.
--
-- ---------------------------------------------------------------------------
-- HOW TO ADD ADMINS (run in the Supabase dashboard SQL editor, not here).
-- Replace the two emails with the real ones:
--
--   insert into app_admins (profile_id, note)
--   select id, 'Gilang' from alumni_profiles where email = 'GILANG_EMAIL'
--   on conflict (profile_id) do nothing;
--
--   insert into app_admins (profile_id, note)
--   select id, 'Maria' from alumni_profiles where email = 'MARIA_EMAIL'
--   on conflict (profile_id) do nothing;
--
-- If "INSERT 0 0" appears, no profile has that exact email. Look for it:
--   select id, name, email from alumni_profiles where email ilike '%gilang%';
-- Check who is admin:
--   select a.profile_id, p.name, p.email, a.note from app_admins a
--   join alumni_profiles p on p.id = a.profile_id;
-- ---------------------------------------------------------------------------
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_app_admins.sql
-- ============================================================================

create table if not exists app_admins (
  profile_id uuid primary key references alumni_profiles (id),
  added_at timestamptz not null default now(),
  note text
);
alter table app_admins enable row level security;
revoke all on app_admins from public, anon, authenticated;

-- The one question the app may ask.
create or replace function is_app_admin(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_profile is not null
     and exists (select 1 from app_admins where profile_id = p_profile);
$$;
revoke execute on function is_app_admin(uuid) from public;
grant execute on function is_app_admin(uuid) to anon, authenticated;

-- Internal guard used by every admin function.
create or replace function app_admin_assert(p_profile uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not is_app_admin(p_profile) then raise exception 'not_admin'; end if;
end;
$$;
revoke execute on function app_admin_assert(uuid) from public, anon, authenticated;

-- ------------------------------------------------- old functions, redefined ---
-- The old callers (and the passphrase argument) keep the same names, but the
-- check is now app_admins. The key argument is accepted and IGNORED.
create or replace function marketplace_is_admin(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select is_app_admin(p_profile);
$$;

create or replace function marketplace_admin_authorized(p_admin uuid, p_key text)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select is_app_admin(p_admin);
$$;
revoke execute on function marketplace_admin_authorized(uuid, text) from public, anon, authenticated;

create or replace function marketplace_admin_pending(p_admin uuid, p_key text default null)
returns setof marketplace_listings
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select * from marketplace_listings
    where status = 'pending'
    order by created_at asc;
end;
$$;

-- Approve (from pending or rejected) or reject (from pending or approved,
-- reason required). Records who decided.
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
  perform app_admin_assert(p_admin);
  if p_decision not in ('approved', 'rejected') then
    raise exception 'invalid_decision';
  end if;
  if p_decision = 'rejected' and nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'reason_required';
  end if;

  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if p_decision = 'approved' and v.status not in ('pending', 'rejected') then
    raise exception 'invalid_state';
  end if;
  if p_decision = 'rejected' and v.status not in ('pending', 'approved') then
    raise exception 'invalid_state';
  end if;

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
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select r.listing_id, count(*)::bigint
    from marketplace_reports r
    group by r.listing_id
    order by count(*) desc;
end;
$$;

-- ----------------------------------------------------------- businesses ---
alter table businesses add column if not exists reviewed_by uuid references alumni_profiles (id);
alter table businesses add column if not exists reviewed_at timestamptz;

-- Every business, pending first, then newest. Optional status filter.
create or replace function admin_businesses_list(p_admin uuid, p_status text default null)
returns table (
  id uuid,
  owner_id uuid,
  owner_name text,
  name text,
  description text,
  category text,
  social_link text,
  website_link text,
  requested_band text,
  approved_band text,
  status text,
  rejection_reason text,
  unlimited_until date,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select b.id, b.owner_id, p.name, b.name, b.description, b.category,
           b.social_link, b.website_link, b.requested_band, b.approved_band,
           b.status, b.rejection_reason, b.unlimited_until, b.created_at
    from businesses b
    join alumni_profiles p on p.id = b.owner_id
    where p_status is null or b.status = p_status
    order by (b.status = 'pending') desc, b.created_at desc;
end;
$$;

-- approve (pending or rejected; needs one of the four bands), reject
-- (pending only; reason required), suspend (approved only; reason optional),
-- restore (suspended only). Sets status and approved_band ONLY.
create or replace function admin_business_decide(
  p_admin uuid,
  p_business uuid,
  p_action text,
  p_band text default null,
  p_reason text default null
)
returns businesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v businesses;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  perform app_admin_assert(p_admin);
  if p_action is null or p_action not in ('approve', 'reject', 'suspend', 'restore') then
    raise exception 'invalid_action';
  end if;
  if char_length(coalesce(v_reason, '')) > 300 then raise exception 'reason_too_long'; end if;

  select * into v from businesses where id = p_business for update;
  if not found then raise exception 'not_found'; end if;

  if p_action = 'approve' then
    if v.status not in ('pending', 'rejected') then raise exception 'invalid_state'; end if;
    if p_band is null or p_band not in ('micro', 'small', 'medium', 'large') then
      raise exception 'invalid_band';
    end if;
    update businesses set status = 'approved', approved_band = p_band, rejection_reason = null,
      reviewed_by = p_admin, reviewed_at = now() where id = p_business returning * into v;
  elsif p_action = 'reject' then
    if v.status <> 'pending' then raise exception 'invalid_state'; end if;
    if v_reason is null then raise exception 'reason_required'; end if;
    update businesses set status = 'rejected', rejection_reason = v_reason,
      reviewed_by = p_admin, reviewed_at = now() where id = p_business returning * into v;
  elsif p_action = 'suspend' then
    if v.status <> 'approved' then raise exception 'invalid_state'; end if;
    update businesses set status = 'suspended', rejection_reason = v_reason,
      reviewed_by = p_admin, reviewed_at = now() where id = p_business returning * into v;
  else
    if v.status <> 'suspended' then raise exception 'invalid_state'; end if;
    if v.approved_band is null then raise exception 'invalid_band'; end if;
    update businesses set status = 'approved', rejection_reason = null,
      reviewed_by = p_admin, reviewed_at = now() where id = p_business returning * into v;
  end if;
  return v;
end;
$$;

revoke execute on function marketplace_is_admin(uuid) from public;
revoke execute on function marketplace_admin_pending(uuid, text) from public;
revoke execute on function marketplace_review_listing(uuid, uuid, text, text, text) from public;
revoke execute on function marketplace_report_counts(uuid, text) from public;
revoke execute on function admin_businesses_list(uuid, text) from public;
revoke execute on function admin_business_decide(uuid, uuid, text, text, text) from public;
grant execute on function marketplace_is_admin(uuid) to anon, authenticated;
grant execute on function marketplace_admin_pending(uuid, text) to anon, authenticated;
grant execute on function marketplace_review_listing(uuid, uuid, text, text, text) to anon, authenticated;
grant execute on function marketplace_report_counts(uuid, text) to anon, authenticated;
grant execute on function admin_businesses_list(uuid, text) to anon, authenticated;
grant execute on function admin_business_decide(uuid, uuid, text, text, text) to anon, authenticated;
