-- Rollback for 20261030160000_categories.sql.
-- Rows that use a new category (for example "Beauty & Health") must be moved
-- to one of the five old names first, or the CHECKs below will refuse to come
-- back. Check with:
--   select category, count(*) from businesses group by 1;
--   select category, count(*) from marketplace_listings group by 1;

drop trigger if exists trg_marketplace_category on marketplace_listings;
drop trigger if exists trg_business_category on businesses;
drop function if exists category_must_be_active();

alter table marketplace_listings drop constraint if exists marketplace_listings_category_fkey;
alter table businesses drop constraint if exists businesses_category_fkey;

alter table marketplace_listings drop constraint if exists marketplace_listings_category_check;
alter table marketplace_listings add constraint marketplace_listings_category_check
  check (category in ('Food & Drink', 'Fashion', 'Electronics', 'Services', 'Other'));

alter table businesses drop constraint if exists businesses_category_check;
alter table businesses add constraint businesses_category_check
  check (category in ('Food & Drink', 'Fashion', 'Electronics', 'Services', 'Other'));

-- business_register() and business_update() go back to the fixed list by
-- re-running their definitions in 20261016090000_instagram_required.sql.

drop policy if exists "categories_read" on categories;
drop table if exists categories;
