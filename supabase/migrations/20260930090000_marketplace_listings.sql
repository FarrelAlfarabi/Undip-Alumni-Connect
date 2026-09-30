-- ============================================================================
-- Marketplace demo: listings table (alumni-to-alumni, dummy data, no payments)
--
-- Follows the base branch's auth model: the app has NO real login, so every
-- request reaches Postgres as `anon` and auth.uid() is always null. RLS
-- therefore cannot know who the caller is. What this migration does:
--   - Anyone can READ `approved` listings directly. pending / rejected /
--     sold rows are invisible to direct reads.
--   - Nobody can write the table directly (no insert/update/delete policy,
--     privileges revoked). All writes go through the SECURITY DEFINER
--     functions in 20260930090200_marketplace_functions.sql, which check
--     ownership / subscriber / admin against the profile id the app passes
--     in. That id is NOT authenticated, so those checks stop accidents and
--     casual abuse, not someone who deliberately passes another profile's
--     id. Real enforcement needs real Supabase Auth (see README).
--
-- Idempotent: safe to re-run.
-- ============================================================================

create table if not exists marketplace_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references alumni_profiles (id),
  title text not null
    check (char_length(btrim(title)) between 3 and 100),
  description text not null
    check (char_length(btrim(description)) between 1 and 2000),
  price_idr integer not null check (price_idr >= 0),
  category text not null
    check (category in ('Food & Drink', 'Fashion', 'Electronics', 'Services', 'Other')),
  city text not null check (char_length(btrim(city)) > 0),
  image_url text not null,
  shop_url text
    check (shop_url is null or shop_url ~* '^https?://\S+$'),
  contact_info text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'sold')),
  rejected_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_at timestamptz,
  constraint marketplace_listings_contact_present check (
    nullif(btrim(coalesce(shop_url, '')), '') is not null
    or nullif(btrim(coalesce(contact_info, '')), '') is not null
  ),
  constraint marketplace_listings_rejected_has_reason check (
    status <> 'rejected' or nullif(btrim(coalesce(rejected_reason, '')), '') is not null
  )
);

create index if not exists idx_marketplace_listings_status_created
  on marketplace_listings (status, created_at desc);
create index if not exists idx_marketplace_listings_category
  on marketplace_listings (category);
create index if not exists idx_marketplace_listings_seller
  on marketplace_listings (seller_id);

alter table marketplace_listings enable row level security;

drop policy if exists "marketplace_listings_select_approved" on marketplace_listings;
create policy "marketplace_listings_select_approved" on marketplace_listings
  for select to anon, authenticated
  using (status = 'approved');

-- No insert/update/delete policies on purpose. Belt and braces: also drop
-- the table privileges so a future permissive policy added by mistake does
-- not silently open writes.
revoke insert, update, delete, truncate on marketplace_listings from anon, authenticated;

-- Demo admins. RLS is on with no policies and privileges are revoked, so
-- the list itself is unreadable through the API; only the SECURITY DEFINER
-- functions look at it. Kept separate from alumni_profiles on purpose:
-- alumni_profiles is world-readable and anon-updatable, so a flag there
-- would be visible and (without touching the shared column-lock trigger)
-- editable by anyone.
create table if not exists marketplace_admins (
  profile_id uuid primary key references alumni_profiles (id),
  created_at timestamptz not null default now()
);

alter table marketplace_admins enable row level security;
revoke all on marketplace_admins from anon, authenticated;
