-- Undo 20261003110000_marketplace_business_products.sql. Safe to run twice.
-- Puts back the closed posting function from the "remove subscription"
-- migration and the old select policy. WARNING: drops marketplace_listings.business_id
-- and posting_plans (the link from products to businesses is lost).
drop function if exists business_my_usage(uuid);
drop function if exists marketplace_create_listing(uuid, uuid, text, text, integer, text, text, text, text, text);
drop trigger if exists marketplace_listings_enforce_business_trigger on marketplace_listings;
drop function if exists marketplace_listings_enforce_business();

drop policy if exists "marketplace_listings_select_approved" on marketplace_listings;
create policy "marketplace_listings_select_approved" on marketplace_listings
  for select to anon, authenticated
  using (status = 'approved');

drop function if exists business_check_can_post(uuid, uuid);
drop function if exists business_post_allowance(uuid);
drop function if exists marketplace_business_visible(uuid);
alter table marketplace_listings drop column if exists business_id;
drop table if exists posting_plans;

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
begin
  raise exception 'posting_closed';
end;
$$;
revoke execute on function marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text) from public;
grant execute on function marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text) to anon, authenticated;

-- Back to "every edit returns the listing to review".
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
