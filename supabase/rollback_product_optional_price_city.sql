-- Undo 20261105130000_product_optional_price_city.sql. Safe to run twice.
-- Products with no price or city get Rp 0 and "-" so the old rules hold.
drop function if exists marketplace_create_listing(uuid, uuid, text, text, integer, boolean, text, text, text, text, text);
drop function if exists marketplace_update_listing(uuid, uuid, text, text, integer, boolean, text, text, text, text, text);
alter table marketplace_listings drop constraint if exists marketplace_listings_price_needed;
alter table marketplace_listings drop constraint if exists marketplace_listings_city_not_blank;
update marketplace_listings set price_idr = 0 where price_idr is null;
update marketplace_listings set city = '-' where city is null;
alter table marketplace_listings alter column price_idr set not null;
alter table marketplace_listings alter column city set not null;
alter table marketplace_listings drop constraint if exists marketplace_listings_city_check;
alter table marketplace_listings add constraint marketplace_listings_city_check check (char_length(btrim(city)) > 0);
alter table marketplace_listings drop column if exists price_negotiable;

create or replace function marketplace_create_listing(
  p_seller uuid, p_business uuid, p_title text, p_description text,
  p_price_idr integer, p_category text, p_city text, p_image_url text,
  p_shop_url text, p_contact_info text
)
returns marketplace_listings
language plpgsql security definer set search_path = public
as $$
declare v marketplace_listings;
begin
  perform assert_caller(p_seller);
  perform business_check_can_post(p_seller, p_business);
  insert into marketplace_listings
    (seller_id, business_id, title, description, price_idr, category, city,
     image_url, shop_url, contact_info, status, approved_at)
  values
    (p_seller, p_business, btrim(p_title), btrim(p_description), p_price_idr,
     p_category, btrim(p_city), p_image_url, nullif(btrim(p_shop_url), ''),
     nullif(btrim(p_contact_info), ''), 'approved', now())
  returning * into v;
  return v;
end;
$$;

create or replace function marketplace_update_listing(
  p_seller uuid, p_listing uuid, p_title text, p_description text,
  p_price_idr integer, p_category text, p_city text, p_image_url text,
  p_shop_url text, p_contact_info text
)
returns marketplace_listings
language plpgsql security definer set search_path = public
as $$
declare v marketplace_listings; v_keep boolean;
begin
  perform assert_caller(p_seller);
  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if v.seller_id <> p_seller then raise exception 'not_owner'; end if;
  if v.status = 'sold' then raise exception 'invalid_state'; end if;
  v_keep := v.business_id is not null and v.status = 'approved';
  update marketplace_listings set
    title = btrim(p_title), description = btrim(p_description),
    price_idr = p_price_idr, category = p_category, city = btrim(p_city),
    image_url = p_image_url, shop_url = nullif(btrim(p_shop_url), ''),
    contact_info = nullif(btrim(p_contact_info), ''),
    status = case when v_keep then 'approved' else 'pending' end,
    rejected_reason = null,
    approved_at = case when v_keep then v.approved_at else null end,
    updated_at = now()
  where id = p_listing returning * into v;
  return v;
end;
$$;
revoke execute on function marketplace_create_listing(uuid, uuid, text, text, integer, text, text, text, text, text) from public;
revoke execute on function marketplace_update_listing(uuid, uuid, text, text, integer, text, text, text, text, text) from public;
grant execute on function marketplace_create_listing(uuid, uuid, text, text, integer, text, text, text, text, text) to anon, authenticated;
grant execute on function marketplace_update_listing(uuid, uuid, text, text, integer, text, text, text, text, text) to anon, authenticated;
