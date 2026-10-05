-- Undo 20261003130000_app_admins.sql. Safe to run twice.
-- Puts the passphrase based admin functions from the security_admin_key
-- migration back. WARNING: drops app_admins (the list of admins) and the two
-- new business columns reviewed_by and reviewed_at.
drop function if exists admin_business_decide(uuid, uuid, text, text, text);
drop function if exists admin_businesses_list(uuid, text);
alter table businesses drop column if exists reviewed_by;
alter table businesses drop column if exists reviewed_at;

create or replace function marketplace_is_admin(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from marketplace_admins where profile_id = p_profile);
$$;

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
  perform pg_sleep(1);
  return false;
end;
$$;
revoke execute on function marketplace_admin_authorized(uuid, text) from public, anon, authenticated;

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

drop function if exists app_admin_assert(uuid);
drop function if exists is_app_admin(uuid);
drop table if exists app_admins;
