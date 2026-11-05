-- ============================================================================
-- Products: optional price (negotiable) and optional city (5 Nov 2026).
--
--   * marketplace_listings.price_idr may be empty (no price written).
--   * marketplace_listings.price_negotiable (default false): the seller is
--     open to negotiating. A product needs a price unless it is negotiable.
--   * marketplace_listings.city may be empty.
--   * marketplace_create_listing / marketplace_update_listing take
--     p_price_negotiable and accept an empty price (only when negotiable) and
--     an empty city.
--
-- Old rows keep their values. Idempotent.
-- Rollback: supabase/rollback_product_optional_price_city.sql
-- ============================================================================

alter table marketplace_listings alter column price_idr drop not null;
alter table marketplace_listings alter column city drop not null;
alter table marketplace_listings
  add column if not exists price_negotiable boolean not null default false;

do $$
declare
  c record;
begin
  for c in
    select conname from pg_constraint
     where conrelid = 'marketplace_listings'::regclass and contype = 'c'
       and pg_get_constraintdef(oid) like '%btrim(city)%'
  loop
    execute format('alter table marketplace_listings drop constraint %I', c.conname);
  end loop;
  if not exists (select 1 from pg_constraint where conname = 'marketplace_listings_city_not_blank') then
    alter table marketplace_listings add constraint marketplace_listings_city_not_blank
      check (city is null or char_length(btrim(city)) > 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'marketplace_listings_price_needed') then
    alter table marketplace_listings add constraint marketplace_listings_price_needed
      check (price_idr is not null or price_negotiable);
  end if;
end $$;

drop function if exists marketplace_create_listing(uuid, uuid, text, text, integer, text, text, text, text, text);
drop function if exists marketplace_update_listing(uuid, uuid, text, text, integer, text, text, text, text, text);

create or replace function marketplace_create_listing(
  p_seller uuid,
  p_business uuid,
  p_title text,
  p_description text,
  p_price_idr integer,
  p_price_negotiable boolean,
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
  perform business_check_can_post(p_seller, p_business);

  insert into marketplace_listings
    (seller_id, business_id, title, description, price_idr, price_negotiable,
     category, city, image_url, shop_url, contact_info, status, approved_at)
  values
    (p_seller, p_business, btrim(p_title), btrim(p_description), p_price_idr,
     coalesce(p_price_negotiable, false), p_category, nullif(btrim(coalesce(p_city, '')), ''),
     p_image_url, nullif(btrim(p_shop_url), ''),
     nullif(btrim(p_contact_info), ''), 'approved', now())
  returning * into v;

  return v;
end;
$$;

create or replace function marketplace_update_listing(
  p_seller uuid,
  p_listing uuid,
  p_title text,
  p_description text,
  p_price_idr integer,
  p_price_negotiable boolean,
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
  v_keep boolean;
begin
  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if v.seller_id <> p_seller then raise exception 'not_owner'; end if;
  if v.status = 'sold' then raise exception 'invalid_state'; end if;

  v_keep := v.business_id is not null and v.status = 'approved';

  update marketplace_listings set
    title = btrim(p_title),
    description = btrim(p_description),
    price_idr = p_price_idr,
    price_negotiable = coalesce(p_price_negotiable, false),
    category = p_category,
    city = nullif(btrim(coalesce(p_city, '')), ''),
    image_url = p_image_url,
    shop_url = nullif(btrim(p_shop_url), ''),
    contact_info = nullif(btrim(p_contact_info), ''),
    status = case when v_keep then 'approved' else 'pending' end,
    rejected_reason = null,
    approved_at = case when v_keep then v.approved_at else null end,
    updated_at = now()
  where id = p_listing
  returning * into v;

  return v;
end;
$$;

revoke execute on function marketplace_create_listing(uuid, uuid, text, text, integer, boolean, text, text, text, text, text) from public;
revoke execute on function marketplace_update_listing(uuid, uuid, text, text, integer, boolean, text, text, text, text, text) from public;
grant execute on function marketplace_create_listing(uuid, uuid, text, text, integer, boolean, text, text, text, text, text) to anon, authenticated;
grant execute on function marketplace_update_listing(uuid, uuid, text, text, integer, boolean, text, text, text, text, text) to anon, authenticated;
