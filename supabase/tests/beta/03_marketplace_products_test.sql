-- Stage 6: products belong to approved businesses, with a posting limit that
-- depends on the approved band. All app calls run as the anon role.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com');

-- Fixtures written as the owner of the database (the dashboard).
create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;
with x as (
  insert into businesses (owner_id, name, description, category, social_link, requested_band, approved_band, status)
  values (jt.pid('ahmad.ramadhan@example.com'), 'Kopi Ahmad', 'Kopi', 'Food & Drink', 'https://instagram.com/kopi_ahmad', 'micro', 'micro', 'approved') returning id)
insert into t_ids select 'micro', id from x;
with x as (
  insert into businesses (owner_id, name, description, category, social_link, requested_band, status)
  values (jt.pid('ahmad.ramadhan@example.com'), 'Belum Disetujui', 'x', 'Other', 'https://instagram.com/belum', 'micro', 'pending') returning id)
insert into t_ids select 'pending', id from x;
with x as (
  insert into businesses (owner_id, name, description, category, social_link, requested_band, approved_band, status)
  values (jt.pid('siti.azizah@example.com'), 'Siti Besar', 'x', 'Services', 'https://instagram.com/siti_besar', 'large', 'large', 'approved') returning id)
insert into t_ids select 'large', id from x;
with x as (
  insert into businesses (owner_id, name, description, category, social_link, requested_band, status)
  values (jt.pid('bagas.prasetyo@example.com'), 'Tanpa Band', 'x', 'Other', 'https://instagram.com/tanpa_band', 'small', 'approved') returning id)
insert into t_ids select 'noband', id from x;

-- Plans: seeded values, editable in the dashboard, hidden from the app.
select jt.assert((select count(*) from posting_plans) = 4, 'four plan rows');
select jt.assert((select free_post_limit from posting_plans where band = 'micro') = 3 and (select monthly_price_idr from posting_plans where band = 'micro') = 25000, 'micro 3 and 25000');
select jt.assert((select free_post_limit from posting_plans where band = 'small') = 3 and (select free_post_limit from posting_plans where band = 'medium') = 3, 'small and medium 3');
select jt.assert((select free_post_limit from posting_plans where band = 'large') = 1 and (select monthly_price_idr from posting_plans where band = 'large') = 200000, 'large 1 and 200000');

set role anon;
select jt.expect_error($q$select * from posting_plans$q$, 'permission denied');
select jt.expect_error($q$update posting_plans set free_post_limit = 999$q$, 'permission denied');

-- The old 9-argument create function is gone.
select jt.expect_error(format($q$select marketplace_create_listing(%L, 'Title ok', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('ahmad.ramadhan@example.com')), 'does not exist');

-- Create rules.
select jt.expect_error(format($q$select marketplace_create_listing(%L, %L, 'Produk satu', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'pending')), 'business_not_approved');
select jt.expect_error(format($q$select marketplace_create_listing(%L, %L, 'Produk satu', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'micro')), 'not_owner');
select jt.expect_error(format($q$select marketplace_create_listing(%L, gen_random_uuid(), 'Produk satu', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('ahmad.ramadhan@example.com')), 'business_not_found');
select jt.expect_error(format($q$select marketplace_create_listing(%L, %L, 'Produk satu', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('bagas.prasetyo@example.com'), (select v from t_ids where k = 'noband')), 'business_not_approved');

-- Micro business: 3 free products, approved at creation.
insert into t_ids select 'p1', id from marketplace_create_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro'), 'Produk satu', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'WA 0800');
insert into t_ids select 'p2', id from marketplace_create_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro'), 'Produk dua', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'WA 0800');
insert into t_ids select 'p3', id from marketplace_create_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro'), 'Produk tiga', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'WA 0800');
select jt.assert((select status from marketplace_my_listings(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'p1')) = 'approved', 'product from an approved business is approved at creation');
select jt.assert((select count(*) from marketplace_listings where business_id = (select v from t_ids where k = 'micro')) = 3, 'the three products are publicly visible');
select jt.expect_error(format($q$select marketplace_create_listing(%L, %L, 'Produk empat', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro')), 'post_limit_reached');

-- The owner sees used, limit and can_post.
select jt.assert((select products_used from business_my_usage(jt.pid('ahmad.ramadhan@example.com')) where business_id = (select v from t_ids where k = 'micro')) = 3, 'used = 3');
select jt.assert((select free_post_limit from business_my_usage(jt.pid('ahmad.ramadhan@example.com')) where business_id = (select v from t_ids where k = 'micro')) = 3, 'limit = 3');
select jt.assert((select can_post from business_my_usage(jt.pid('ahmad.ramadhan@example.com')) where business_id = (select v from t_ids where k = 'micro')) = false, 'cannot post at the limit');
select jt.assert((select unlimited_active from business_my_usage(jt.pid('ahmad.ramadhan@example.com')) where business_id = (select v from t_ids where k = 'micro')) = false, 'not unlimited');

-- Edit and delete always work at the limit. Editing an approved product keeps it approved.
select marketplace_update_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'p1'), 'Produk satu baru', 'desc', 2000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'WA 0800');
select jt.assert((select status from marketplace_my_listings(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'p1')) = 'approved', 'edit keeps an approved business product approved');

-- Sold does not count.
select marketplace_set_sold(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'p3'));
select jt.assert((select products_used from business_my_usage(jt.pid('ahmad.ramadhan@example.com')) where business_id = (select v from t_ids where k = 'micro')) = 2, 'sold product does not count');
insert into t_ids select 'p4', id from marketplace_create_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro'), 'Produk empat', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa');
select jt.expect_error(format($q$select marketplace_create_listing(%L, %L, 'Produk lima', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro')), 'post_limit_reached');
-- Deleted does not count.
select marketplace_delete_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'p4'));
insert into t_ids select 'p5', id from marketplace_create_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro'), 'Produk lima', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa');

-- Large band: only 1 free product.
insert into t_ids select 'L1', id from marketplace_create_listing(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'large'), 'Layanan besar', 'desc', 1000, 'Services', 'Semarang', 'https://x.example/a.png', null, 'wa');
select jt.expect_error(format($q$select marketplace_create_listing(%L, %L, 'Layanan dua', 'desc', 1000, 'Services', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'large')), 'post_limit_reached');
reset role;

-- The limit is data, not code: the dashboard raises it and posting works.
update posting_plans set free_post_limit = 2 where band = 'large';
set role anon;
insert into t_ids select 'L2', id from marketplace_create_listing(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'large'), 'Layanan dua', 'desc', 1000, 'Services', 'Semarang', 'https://x.example/a.png', null, 'wa');
reset role;
update posting_plans set free_post_limit = 1 where band = 'large';

-- Unlimited for one month: set by the dashboard. Today (Jakarta) still counts.
update businesses set unlimited_until = (now() at time zone 'Asia/Jakarta')::date where id = (select v from t_ids where k = 'micro');
set role anon;
select jt.assert((select unlimited_active from business_my_usage(jt.pid('ahmad.ramadhan@example.com')) where business_id = (select v from t_ids where k = 'micro')) = true, 'unlimited today');
insert into t_ids select 'u1', id from marketplace_create_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro'), 'Produk enam', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa');
insert into t_ids select 'u2', id from marketplace_create_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro'), 'Produk tujuh', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa');
reset role;

-- It expires: yesterday is over. Everything stays visible, only new ones are blocked.
update businesses set unlimited_until = (now() at time zone 'Asia/Jakarta')::date - 1 where id = (select v from t_ids where k = 'micro');
set role anon;
select jt.assert((select unlimited_active from business_my_usage(jt.pid('ahmad.ramadhan@example.com')) where business_id = (select v from t_ids where k = 'micro')) = false, 'expired is not unlimited');
select jt.assert((select products_used from business_my_usage(jt.pid('ahmad.ramadhan@example.com')) where business_id = (select v from t_ids where k = 'micro')) = 5, 'five products are counted (over the free limit of 3)');
select jt.assert((select count(*) from marketplace_listings where business_id = (select v from t_ids where k = 'micro')) = 5, 'all five stay visible after expiry');
select jt.expect_error(format($q$select marketplace_create_listing(%L, %L, 'Produk delapan', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro')), 'post_limit_reached');
-- Edit and delete still work while over the limit.
select marketplace_update_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'u1'), 'Produk enam baru', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa');
select marketplace_delete_listing(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'u2'));
reset role;

-- A suspended business hides all its products from everyone.
update businesses set status = 'suspended' where id = (select v from t_ids where k = 'micro');
set role anon;
select jt.assert((select count(*) from marketplace_listings where business_id = (select v from t_ids where k = 'micro')) = 0, 'suspended business: products hidden');
select jt.assert((select count(*) from marketplace_my_listings(jt.pid('ahmad.ramadhan@example.com')) where business_id = (select v from t_ids where k = 'micro')) >= 4, 'owner still sees and can edit their products');
select jt.expect_error(format($q$select marketplace_create_listing(%L, %L, 'Produk sembilan', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'micro')), 'business_not_approved');
reset role;
update businesses set status = 'approved' where id = (select v from t_ids where k = 'micro');
set role anon;
select jt.assert((select count(*) from marketplace_listings where business_id = (select v from t_ids where k = 'micro')) = 4, 'restored business: products visible again');
-- Legacy listings (no business) stay visible and count against nothing.
select jt.assert((select count(*) from marketplace_listings where business_id is null) > 0, 'legacy seed listings still visible');
reset role;

-- Direct insert path: no privileges for the app, and if a grant and a policy
-- were added by mistake the trigger still enforces the rules.
grant select, insert on marketplace_listings to anon;
create policy tmp_open on marketplace_listings for insert to anon with check (true);
set role anon;
select jt.expect_error(format($q$insert into marketplace_listings (seller_id, business_id, title, description, price_idr, category, city, image_url, contact_info, status) values (%L, %L, 'Langsung', 'd', 1, 'Other', 'x', 'https://x.example/a.png', 'wa', 'approved')$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'large')), 'post_limit_reached');
select jt.expect_error(format($q$insert into marketplace_listings (seller_id, title, description, price_idr, category, city, image_url, contact_info, status) values (%L, 'Tanpa bisnis', 'd', 1, 'Other', 'x', 'https://x.example/a.png', 'wa', 'approved')$q$, jt.pid('siti.azizah@example.com')), 'business_required');
select jt.expect_error(format($q$insert into marketplace_listings (seller_id, business_id, title, description, price_idr, category, city, image_url, contact_info, status) values (%L, %L, 'Bisnis orang', 'd', 1, 'Other', 'x', 'https://x.example/a.png', 'wa', 'approved')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'large')), 'not_owner');
reset role;
drop policy tmp_open on marketplace_listings;
revoke all on marketplace_listings from anon;
grant select on marketplace_listings to anon;

rollback;
\o
\echo marketplace product checks passed
