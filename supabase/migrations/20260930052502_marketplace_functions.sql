-- ============================================================================
-- Marketplace demo: write/review functions (SECURITY DEFINER)
--
-- The only way to change marketplace_listings. Each function checks the
-- profile id passed in by the app. That id is NOT authenticated (the app has
-- no Supabase Auth session), so these are guardrails, not real access
-- control. Errors are raised as short codes the app maps to messages:
--   subscriber_required, not_found, not_owner, not_admin, invalid_state,
--   invalid_decision, reason_required
--
-- Idempotent: safe to re-run (create or replace).
-- ============================================================================

create or replace function marketplace_is_admin(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from marketplace_admins where profile_id = p_profile);
$$;

create or replace function marketplace_create_listing(
  p_seller uuid,
  p_title text,
  p_description text,
  p_price_idr integer,
  p_category text,
  p_city text,
  p_image_url text,
  p_shop_url text,
  p_contact_info text
)
returns marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v marketplace_listings;
begin
  if not exists (
    select 1 from alumni_profiles
    where id = p_seller and subscription_status = 'subscribed'
  ) then
    raise exception 'subscriber_required';
  end if;

  insert into marketplace_listings
    (seller_id, title, description, price_idr, category, city, image_url,
     shop_url, contact_info, status)
  values
    (p_seller, btrim(p_title), btrim(p_description), p_price_idr, p_category,
     btrim(p_city), p_image_url, nullif(btrim(p_shop_url), ''),
     nullif(btrim(p_contact_info), ''), 'pending')
  returning * into v;

  return v;
end;
$$;

-- Editing always returns the listing to review (pending), whatever its
-- previous state, and clears any earlier rejection. Sold listings are final.
create or replace function marketplace_update_listing(
  p_seller uuid,
  p_listing uuid,
  p_title text,
  p_description text,
  p_price_idr integer,
  p_category text,
  p_city text,
  p_image_url text,
  p_shop_url text,
  p_contact_info text
)
returns marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v marketplace_listings;
begin
  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if v.seller_id <> p_seller then raise exception 'not_owner'; end if;
  if v.status = 'sold' then raise exception 'invalid_state'; end if;

  update marketplace_listings set
    title = btrim(p_title),
    description = btrim(p_description),
    price_idr = p_price_idr,
    category = p_category,
    city = btrim(p_city),
    image_url = p_image_url,
    shop_url = nullif(btrim(p_shop_url), ''),
    contact_info = nullif(btrim(p_contact_info), ''),
    status = 'pending',
    rejected_reason = null,
    approved_at = null,
    updated_at = now()
  where id = p_listing
  returning * into v;

  return v;
end;
$$;

create or replace function marketplace_set_sold(p_seller uuid, p_listing uuid)
returns marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v marketplace_listings;
begin
  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if v.seller_id <> p_seller then raise exception 'not_owner'; end if;
  if v.status <> 'approved' then raise exception 'invalid_state'; end if;

  update marketplace_listings
  set status = 'sold', updated_at = now()
  where id = p_listing
  returning * into v;

  return v;
end;
$$;

create or replace function marketplace_delete_listing(p_seller uuid, p_listing uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v marketplace_listings;
begin
  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if v.seller_id <> p_seller then raise exception 'not_owner'; end if;

  delete from marketplace_listings where id = p_listing;
end;
$$;

-- The seller's own listings in every status (pending / rejected / sold too).
create or replace function marketplace_my_listings(p_seller uuid)
returns setof marketplace_listings
language sql
stable
security definer
set search_path = public
as $$
  select * from marketplace_listings
  where seller_id = p_seller
  order by created_at desc;
$$;

create or replace function marketplace_admin_pending(p_admin uuid)
returns setof marketplace_listings
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not marketplace_is_admin(p_admin) then raise exception 'not_admin'; end if;
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
  p_reason text default null
)
returns marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v marketplace_listings;
begin
  if not marketplace_is_admin(p_admin) then raise exception 'not_admin'; end if;
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
    updated_at = now()
  where id = p_listing
  returning * into v;

  return v;
end;
$$;

-- Report count per listing, for the admin view only.
create or replace function marketplace_report_counts(p_admin uuid)
returns table (listing_id uuid, report_count bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not marketplace_is_admin(p_admin) then raise exception 'not_admin'; end if;
  return query
    select r.listing_id, count(*)::bigint
    from marketplace_reports r
    group by r.listing_id
    order by count(*) desc;
end;
$$;

-- Supabase auto-grants EXECUTE on new functions to anon/authenticated/public.
-- Grant explicitly and only to the two API roles.
revoke execute on function marketplace_is_admin(uuid) from public;
revoke execute on function marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text) from public;
revoke execute on function marketplace_update_listing(uuid, uuid, text, text, integer, text, text, text, text, text) from public;
revoke execute on function marketplace_set_sold(uuid, uuid) from public;
revoke execute on function marketplace_delete_listing(uuid, uuid) from public;
revoke execute on function marketplace_my_listings(uuid) from public;
revoke execute on function marketplace_admin_pending(uuid) from public;
revoke execute on function marketplace_review_listing(uuid, uuid, text, text) from public;
revoke execute on function marketplace_report_counts(uuid) from public;

grant execute on function marketplace_is_admin(uuid) to anon, authenticated;
grant execute on function marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text) to anon, authenticated;
grant execute on function marketplace_update_listing(uuid, uuid, text, text, integer, text, text, text, text, text) to anon, authenticated;
grant execute on function marketplace_set_sold(uuid, uuid) to anon, authenticated;
grant execute on function marketplace_delete_listing(uuid, uuid) to anon, authenticated;
grant execute on function marketplace_my_listings(uuid) to anon, authenticated;
grant execute on function marketplace_admin_pending(uuid) to anon, authenticated;
grant execute on function marketplace_review_listing(uuid, uuid, text, text) to anon, authenticated;
grant execute on function marketplace_report_counts(uuid) to anon, authenticated;
