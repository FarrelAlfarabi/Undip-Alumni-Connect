-- ============================================================================
-- Marketplace products belong to approved businesses (closed beta, Stage 6).
--
--   * marketplace_listings.business_id (nullable: the 12 old seed listings
--     stay as "legacy" listings, visible, counted against no limit).
--   * Only the owner of an APPROVED business can add a product. A product is
--     approved at creation (no review queue). Admin reject/hide and reports
--     still work (admin functions are redefined in a later migration).
--   * posting_plans: one row per band, editable in the dashboard.
--       micro, small, medium = 3 free products, Rp 25.000 a month
--       large                = 1 free product,  Rp 200.000 a month
--     The numbers are DATA. Nothing in the app or functions hardcodes them.
--   * Allowed to post: unlimited if businesses.unlimited_until is today or
--     later (Jakarta date), else used < free_post_limit of the APPROVED band.
--     "used" = products that are not sold (deleted ones are gone). Over the
--     limit (for example after unlimited expires): every product stays
--     visible, only NEW products are blocked. Edit and delete always work.
--   * The limit is enforced in marketplace_create_listing AND by a trigger
--     for any direct insert path (the app has no such path today).
--   * A suspended business hides all its products (select policy).
--   * No payment code. Payment is collected by hand; unlimited_until is set
--     in the dashboard.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_marketplace_business_products.sql
-- ============================================================================

-- ---------------------------------------------------------------- plans ---
create table if not exists posting_plans (
  band text primary key check (band in ('micro', 'small', 'medium', 'large')),
  free_post_limit integer not null check (free_post_limit >= 0),
  monthly_price_idr integer not null check (monthly_price_idr >= 0)
);
insert into posting_plans (band, free_post_limit, monthly_price_idr) values
  ('micro', 3, 25000),
  ('small', 3, 25000),
  ('medium', 3, 25000),
  ('large', 1, 200000)
on conflict (band) do nothing;
alter table posting_plans enable row level security;
revoke all on posting_plans from public, anon, authenticated;

-- --------------------------------------------------------- business link ---
alter table marketplace_listings
  add column if not exists business_id uuid references businesses (id);
create index if not exists idx_marketplace_listings_business on marketplace_listings (business_id);

-- ------------------------------------------------------------ visibility ---
-- Used inside the select policy. SECURITY DEFINER because the app has no
-- right to read the businesses table.
create or replace function marketplace_business_visible(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_business is null
      or exists (select 1 from businesses where id = p_business and status = 'approved');
$$;
revoke execute on function marketplace_business_visible(uuid) from public;
grant execute on function marketplace_business_visible(uuid) to anon, authenticated;

drop policy if exists "marketplace_listings_select_approved" on marketplace_listings;
create policy "marketplace_listings_select_approved" on marketplace_listings
  for select to anon, authenticated
  using (status = 'approved' and marketplace_business_visible(business_id));

-- ------------------------------------------------------------ allowance ---
-- One place that works out how many products a business may have.
create or replace function business_post_allowance(p_business uuid)
returns table (
  approved_band text,
  free_post_limit integer,
  products_used integer,
  unlimited_active boolean,
  can_post boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  b businesses;
  v_limit integer;
  v_used integer;
  v_unlimited boolean;
begin
  select * into b from businesses where id = p_business;
  if not found then return; end if;

  select coalesce((select pp.free_post_limit from posting_plans pp where pp.band = b.approved_band), 0)
    into v_limit;
  select count(*)::integer into v_used
    from marketplace_listings l
    where l.business_id = p_business and l.status <> 'sold';
  v_unlimited := b.unlimited_until is not null
    and b.unlimited_until >= (now() at time zone 'Asia/Jakarta')::date;

  return query select
    b.approved_band,
    v_limit,
    v_used,
    v_unlimited,
    (b.status = 'approved' and b.approved_band is not null and (v_unlimited or v_used < v_limit));
end;
$$;
revoke execute on function business_post_allowance(uuid) from public, anon, authenticated;

-- Raises the right code when this seller may NOT add a product to this
-- business. Used by the create function and by the insert trigger.
create or replace function business_check_can_post(p_seller uuid, p_business uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  b businesses;
  a record;
begin
  if p_business is null then raise exception 'business_required'; end if;
  select * into b from businesses where id = p_business for update;
  if not found then raise exception 'business_not_found'; end if;
  if b.owner_id <> p_seller then raise exception 'not_owner'; end if;
  if b.status <> 'approved' or b.approved_band is null then
    raise exception 'business_not_approved';
  end if;
  select * into a from business_post_allowance(p_business);
  if not a.can_post then raise exception 'post_limit_reached'; end if;
end;
$$;
revoke execute on function business_check_can_post(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------- insert guard ---
-- For any direct insert by the app roles. The dashboard (role none /
-- postgres / service_role) is not restricted. The create function below also
-- passes through this trigger, which only repeats the same check.
create or replace function marketplace_listings_enforce_business()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('role', true), '') not in ('anon', 'authenticated') then
    return new;
  end if;
  perform business_check_can_post(new.seller_id, new.business_id);
  return new;
end;
$$;
revoke execute on function marketplace_listings_enforce_business() from public, anon, authenticated;

drop trigger if exists marketplace_listings_enforce_business_trigger on marketplace_listings;
create trigger marketplace_listings_enforce_business_trigger
  before insert on marketplace_listings
  for each row execute function marketplace_listings_enforce_business();

-- --------------------------------------------------------------- create ---
drop function if exists marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text);

create or replace function marketplace_create_listing(
  p_seller uuid,
  p_business uuid,
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

revoke execute on function marketplace_create_listing(uuid, uuid, text, text, integer, text, text, text, text, text) from public;
grant execute on function marketplace_create_listing(uuid, uuid, text, text, integer, text, text, text, text, text) to anon, authenticated;

-- ---------------------------------------------------------------- update ---
-- A product of a business stays approved when its owner edits it (like
-- creation, no review). Anything else (a legacy listing, or one an admin
-- rejected) goes back to review, as before. Sold products are final.
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
    category = p_category,
    city = btrim(p_city),
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

-- ----------------------------------------------------------------- usage ---
-- For the owner screen: per business, the limit, how many are used, and
-- whether unlimited posting is on. No price here on purpose.
create or replace function business_my_usage(p_owner uuid)
returns table (
  business_id uuid,
  free_post_limit integer,
  products_used integer,
  unlimited_active boolean,
  can_post boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select b.id, a.free_post_limit, a.products_used, a.unlimited_active, a.can_post
  from businesses b
  cross join lateral business_post_allowance(b.id) a
  where b.owner_id = p_owner
  order by b.created_at desc;
$$;
revoke execute on function business_my_usage(uuid) from public;
grant execute on function business_my_usage(uuid) to anon, authenticated;
