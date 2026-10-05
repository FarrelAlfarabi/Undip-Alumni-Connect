-- Marketplace SQL/RLS checks. Run through run_local.sh (throwaway local
-- Postgres with seed.sql + seed_marketplace.sql loaded). Any failure raises
-- an exception and stops the run.
--
-- Roles are simulated with `set role anon`, as the app only ever calls
-- Postgres as anon. There is no auth.uid(), so "seller", "other user" and
-- "admin" below are just different profile ids passed to the functions.
-- That mirrors what the deployed app can and cannot enforce.

\set ON_ERROR_STOP on
\o /dev/null

create schema t;
create table t.ctx (k text primary key, v text);
create function t.assert(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is not true then raise exception 'ASSERT FAILED: %', msg; end if;
end $$;
-- Runs p_sql and requires it to fail with a message matching p_pattern.
create function t.expect_error(p_sql text, p_pattern text) returns void language plpgsql as $$
declare ok boolean := false;
begin
  begin
    execute p_sql;
    ok := true;
  exception when others then
    if sqlerrm !~ p_pattern then
      raise exception 'ASSERT FAILED: expected error ~ "%" but got "%" for: %', p_pattern, sqlerrm, p_sql;
    end if;
  end;
  if ok then raise exception 'ASSERT FAILED: expected error ~ "%" but statement succeeded: %', p_pattern, p_sql; end if;
end $$;
create function t.pid(p_email text) returns uuid language sql stable as $$
  select id from public.alumni_profiles where email = p_email $$;
-- The admin passphrase used by these tests (a test value, not a real secret).
create function t.k() returns text language sql immutable as $$ select 'test-passphrase-1234'::text $$;
grant usage on schema t to public;
grant select, insert, update on t.ctx to public;

-- Fixture profiles (postgres role): A = bunga (subscribed, seller),
-- B = siti (made subscribed here, second seller), F = ahmad (free),
-- admin = farrel (seeded admin).
update alumni_profiles set subscription_status = 'subscribed'
  where email = 'siti.azizah@example.com';

-- Admin passphrase (owner-only helper), then the admin functions can be used.
select marketplace_set_admin_key(t.pid('demo.admin@example.com'), t.k());

select t.assert((select count(*) from marketplace_listings) = 12, 'seed has 12 listings');
select t.assert((select count(*) from marketplace_listings where status = 'approved') = 10, 'seed has 10 approved');
select t.assert((select count(*) from marketplace_listings where status = 'pending') = 2, 'seed has 2 pending');
select t.assert((select count(distinct category) from marketplace_listings) = 5, 'seed covers 5 categories');
select t.assert((select count(*) from marketplace_listings where shop_url is null and contact_info is null) = 0, 'seed rows all have shop or contact');

-- ---------------------------------------------------------------- browse ---
set role anon;
select t.assert((select count(*) from marketplace_listings) = 10, 'anon sees exactly the 10 approved');
select t.assert((select count(*) from marketplace_listings where status <> 'approved') = 0, 'anon sees no non-approved row');
select t.assert((select count(*) from marketplace_listings where status = 'pending') = 0, 'anon cannot see pending');
select t.assert((select count(*) from alumni_profiles) > 0, 'anon can still read profiles (seller card join)');
reset role;

-- ------------------------------------------------- direct writes are closed ---
set role anon;
select t.expect_error(
  $q$insert into marketplace_listings (seller_id, title, description, price_idr, category, city, image_url, contact_info)
     values (t.pid('bunga.ayu@example.com'), 'Direct insert', 'x', 1, 'Other', 'Jakarta', 'https://x.example.com/i.jpg', 'a')$q$,
  'permission denied');
select t.expect_error($q$update marketplace_listings set status = 'approved'$q$, 'permission denied');
select t.expect_error($q$delete from marketplace_listings$q$, 'permission denied');
reset role;

-- RLS alone (without the privilege revoke) must also block anon writes.
begin;
grant insert, update, delete on marketplace_listings to anon;
set local role anon;
select t.expect_error(
  $q$insert into marketplace_listings (seller_id, title, description, price_idr, category, city, image_url, contact_info)
     values (t.pid('bunga.ayu@example.com'), 'Direct insert', 'x', 1, 'Other', 'Jakarta', 'https://x.example.com/i.jpg', 'a')$q$,
  'row-level security');
-- update/delete are filtered to zero rows by RLS (no policy), not errors.
with u as (update marketplace_listings set status = 'approved' returning 1)
  select t.assert((select count(*) from u) = 0, 'RLS: anon update touches 0 rows');
with d as (delete from marketplace_listings returning 1)
  select t.assert((select count(*) from d) = 0, 'RLS: anon delete touches 0 rows');
rollback;
select t.assert((select count(*) from marketplace_listings) = 12, 'nothing changed after direct-write attempts');

-- ---------------------------------------------- admins table is invisible ---
set role anon;
select t.expect_error('select * from marketplace_admins', 'permission denied');
select t.assert(marketplace_is_admin(t.pid('demo.admin@example.com')) is true, 'is_admin true for admin');
select t.assert(marketplace_is_admin(t.pid('bunga.ayu@example.com')) is false, 'is_admin false for non-admin');

-- ------------------------------------------- admin passphrase (audit SA-04) ---
reset role;
select t.assert((select key_hash from marketplace_admins limit 1) like '$2%', 'passphrase is stored as a bcrypt hash');
select t.assert((select key_hash from marketplace_admins limit 1) not like '%test-passphrase%', 'passphrase is not stored in plain text');
select t.expect_error(format($q$select marketplace_set_admin_key(%L, 'short')$q$, t.pid('demo.admin@example.com')), 'at least 16');
set role anon;
select t.expect_error(format($q$select marketplace_set_admin_key(%L, 'a-long-passphrase-anon-1')$q$, t.pid('demo.admin@example.com')), 'permission denied');
select t.expect_error(format($q$select marketplace_admin_authorized(%L, t.k())$q$, t.pid('demo.admin@example.com')), 'permission denied');
-- the admin id alone (or with a wrong key) is refused, whatever the signature
select t.expect_error(format($q$select * from marketplace_admin_pending(%L)$q$, t.pid('demo.admin@example.com')), 'not_admin');
select t.expect_error(format($q$select * from marketplace_admin_pending(%L, 'wrong-passphrase-0000')$q$, t.pid('demo.admin@example.com')), 'not_admin');
select t.expect_error(format($q$select marketplace_review_listing(%L, %L, 'approved')$q$, t.pid('demo.admin@example.com'), (select id from marketplace_listings limit 1)), 'not_admin');
select t.expect_error(format($q$select * from marketplace_report_counts(%L)$q$, t.pid('demo.admin@example.com')), 'not_admin');
-- the old id-only functions no longer exist
select t.expect_error(format($q$select * from marketplace_admin_pending(%L, null, null)$q$, t.pid('demo.admin@example.com')), 'does not exist');
reset role;
-- an admin with no passphrase set cannot act
insert into alumni_profiles (id, nim, name, faculty, major, graduation_year, email)
  values ('99999999-0000-4000-8000-000000000001','Z1','No Key Admin','F','M',2020,'nokey.admin@example.com');
insert into marketplace_admins (profile_id) values ('99999999-0000-4000-8000-000000000001');
set role anon;
select t.expect_error(format($q$select * from marketplace_admin_pending(%L, t.k())$q$, '99999999-0000-4000-8000-000000000001'), 'not_admin');
reset role;
delete from marketplace_admins where profile_id = '99999999-0000-4000-8000-000000000001';
delete from alumni_profiles where id = '99999999-0000-4000-8000-000000000001';
reset role;

-- ------------------------------------------------------------ create ---
set role anon;
-- Non-subscriber cannot create.
select t.expect_error(
  format($q$select marketplace_create_listing(%L, 'Kue Kering', 'Enak', 30000, 'Food & Drink', 'Jakarta', 'https://img.example.com/a.jpg', null, 'wa 0800-0000-0000')$q$,
         t.pid('ahmad.ramadhan@example.com')),
  'subscriber_required');
-- Subscriber can; new row is pending.
insert into t.ctx select 'own', (marketplace_create_listing(
  t.pid('bunga.ayu@example.com'), '  Kue Kering  ', 'Enak', 30000, 'Food & Drink', 'Jakarta',
  'https://img.example.com/a.jpg', '', 'wa 0800-0000-0000')).id;
select t.assert((select status from marketplace_my_listings(t.pid('bunga.ayu@example.com')) where id = (select v::uuid from t.ctx where k = 'own')) = 'pending', 'new listing is pending');
select t.assert((select title from marketplace_my_listings(t.pid('bunga.ayu@example.com')) where id = (select v::uuid from t.ctx where k = 'own')) = 'Kue Kering', 'title is trimmed');
select t.assert((select shop_url is null from marketplace_my_listings(t.pid('bunga.ayu@example.com')) where id = (select v::uuid from t.ctx where k = 'own')), 'empty shop_url stored as null');
-- Pending listing is invisible to browse and to other sellers' "mine".
select t.assert((select count(*) from marketplace_listings where id = (select v::uuid from t.ctx where k = 'own')) = 0, 'pending invisible to browse');
select t.assert((select count(*) from marketplace_my_listings(t.pid('siti.azizah@example.com')) where id = (select v::uuid from t.ctx where k = 'own')) = 0, 'other user cannot see my pending');
reset role;

-- ----------------------------------------------------------- constraints ---
set role anon;
select t.expect_error(
  format($q$select marketplace_create_listing(%L, 'Tanpa kontak', 'x', 1000, 'Other', 'Jakarta', 'https://img.example.com/a.jpg', ' ', '  ')$q$, t.pid('bunga.ayu@example.com')),
  'marketplace_listings_contact_present');
select t.expect_error(
  format($q$select marketplace_create_listing(%L, 'Harga minus', 'x', -1, 'Other', 'Jakarta', 'https://img.example.com/a.jpg', null, 'a')$q$, t.pid('bunga.ayu@example.com')),
  'price_idr');
select t.expect_error(
  format($q$select marketplace_create_listing(%L, 'Kategori salah', 'x', 1, 'Weapons', 'Jakarta', 'https://img.example.com/a.jpg', null, 'a')$q$, t.pid('bunga.ayu@example.com')),
  'category');
select t.expect_error(
  format($q$select marketplace_create_listing(%L, 'Url salah', 'x', 1, 'Other', 'Jakarta', 'https://img.example.com/a.jpg', 'javascript:alert(1)', null)$q$, t.pid('bunga.ayu@example.com')),
  'shop_url');
select t.expect_error(
  format($q$select marketplace_create_listing(%L, 'ab', 'x', 1, 'Other', 'Jakarta', 'https://img.example.com/a.jpg', null, 'a')$q$, t.pid('bunga.ayu@example.com')),
  'title');
reset role;

-- ------------------------------------------------ ownership and approval ---
set role anon;
-- Another user cannot edit / mark sold / delete someone else's listing.
select t.expect_error(
  format($q$select marketplace_update_listing(%L, %L, 'Hijack', 'x', 1, 'Other', 'Jakarta', 'https://img.example.com/a.jpg', null, 'a')$q$,
         t.pid('siti.azizah@example.com'), (select v from t.ctx where k = 'own')),
  'not_owner');
select t.expect_error(
  format($q$select marketplace_set_sold(%L, %L)$q$, t.pid('siti.azizah@example.com'), (select v from t.ctx where k = 'own')),
  'not_owner');
select t.expect_error(
  format($q$select marketplace_delete_listing(%L, %L)$q$, t.pid('siti.azizah@example.com'), (select v from t.ctx where k = 'own')),
  'not_owner');
-- Seller cannot approve own listing (not an admin).
select t.expect_error(
  format($q$select marketplace_review_listing(%L, %L, 'approved', null, t.k())$q$, t.pid('bunga.ayu@example.com'), (select v from t.ctx where k = 'own')),
  'not_admin');
select t.expect_error(
  format($q$select marketplace_admin_pending(%L, t.k())$q$, t.pid('bunga.ayu@example.com')), 'not_admin');
-- Cannot mark a pending listing sold.
select t.expect_error(
  format($q$select marketplace_set_sold(%L, %L)$q$, t.pid('bunga.ayu@example.com'), (select v from t.ctx where k = 'own')),
  'invalid_state');
-- Admin flow: queue, reject needs a reason, reject, approve.
select t.assert((select count(*) from marketplace_admin_pending(t.pid('demo.admin@example.com'), t.k())) = 3, 'admin queue = 2 seeded + 1 new');
select t.expect_error(
  format($q$select marketplace_review_listing(%L, %L, 'rejected', '  ', t.k())$q$, t.pid('demo.admin@example.com'), (select v from t.ctx where k = 'own')),
  'reason_required');
select t.expect_error(
  format($q$select marketplace_review_listing(%L, %L, 'sold', null, t.k())$q$, t.pid('demo.admin@example.com'), (select v from t.ctx where k = 'own')),
  'invalid_decision');
select marketplace_review_listing(t.pid('demo.admin@example.com'), (select v::uuid from t.ctx where k = 'own'), 'rejected', 'Foto kurang jelas', t.k());
select t.assert((select status || '|' || rejected_reason from marketplace_my_listings(t.pid('bunga.ayu@example.com')) where id = (select v::uuid from t.ctx where k = 'own')) = 'rejected|Foto kurang jelas', 'seller sees rejection + reason');
select t.assert((select count(*) from marketplace_listings where id = (select v::uuid from t.ctx where k = 'own')) = 0, 'rejected invisible to browse');
-- Editing a rejected listing resubmits it (pending, reason cleared).
select marketplace_update_listing(t.pid('bunga.ayu@example.com'), (select v::uuid from t.ctx where k = 'own'),
  'Kue Kering Premium', 'Foto baru', 32000, 'Food & Drink', 'Jakarta', 'https://img.example.com/b.jpg', null, 'wa 0800-0000-0000');
select t.assert((select status || '|' || coalesce(rejected_reason, 'null') from marketplace_my_listings(t.pid('bunga.ayu@example.com')) where id = (select v::uuid from t.ctx where k = 'own')) = 'pending|null', 'edit after reject -> pending, reason cleared');
select marketplace_review_listing(t.pid('demo.admin@example.com'), (select v::uuid from t.ctx where k = 'own'), 'approved', null, t.k());
select t.assert((select count(*) from marketplace_listings where id = (select v::uuid from t.ctx where k = 'own') and approved_at is not null) = 1, 'approved is visible with approved_at');
-- Cannot review twice.
select t.expect_error(
  format($q$select marketplace_review_listing(%L, %L, 'approved', null, t.k())$q$, t.pid('demo.admin@example.com'), (select v from t.ctx where k = 'own')),
  'invalid_state');
-- Editing an approved listing sends it back to pending and hides it.
select marketplace_update_listing(t.pid('bunga.ayu@example.com'), (select v::uuid from t.ctx where k = 'own'),
  'Kue Kering Premium', 'Deskripsi baru', 33000, 'Food & Drink', 'Jakarta', 'https://img.example.com/b.jpg', null, 'wa 0800-0000-0000');
select t.assert((select status from marketplace_my_listings(t.pid('bunga.ayu@example.com')) where id = (select v::uuid from t.ctx where k = 'own')) = 'pending', 'edit approved -> pending');
select t.assert((select approved_at is null from marketplace_my_listings(t.pid('bunga.ayu@example.com')) where id = (select v::uuid from t.ctx where k = 'own')), 'approved_at cleared on edit');
select t.assert((select count(*) from marketplace_listings where id = (select v::uuid from t.ctx where k = 'own')) = 0, 'edited listing hidden until re-approved');
select marketplace_review_listing(t.pid('demo.admin@example.com'), (select v::uuid from t.ctx where k = 'own'), 'approved', null, t.k());
-- Sold: hidden from browse (simplest option), still in seller's list, final.
select marketplace_set_sold(t.pid('bunga.ayu@example.com'), (select v::uuid from t.ctx where k = 'own'));
select t.assert((select count(*) from marketplace_listings where id = (select v::uuid from t.ctx where k = 'own')) = 0, 'sold hidden from browse');
select t.assert((select status from marketplace_my_listings(t.pid('bunga.ayu@example.com')) where id = (select v::uuid from t.ctx where k = 'own')) = 'sold', 'sold visible to seller');
select t.expect_error(
  format($q$select marketplace_update_listing(%L, %L, 'x1x', 'x', 1, 'Other', 'Jakarta', 'https://img.example.com/a.jpg', null, 'a')$q$, t.pid('bunga.ayu@example.com'), (select v from t.ctx where k = 'own')),
  'invalid_state');
reset role;

-- --------------------------------------------------------------- reports ---
set role anon;
-- Report an approved seeded listing.
insert into marketplace_reports (listing_id, reporter, reason, note)
  values ('a0000000-0000-4000-8000-000000000001', t.pid('ahmad.ramadhan@example.com'), 'spam', 'iklan berulang');
insert into marketplace_reports (listing_id, reporter, reason)
  values ('a0000000-0000-4000-8000-000000000001', t.pid('siti.azizah@example.com'), 'misleading');
-- Duplicate report by the same reporter is rejected.
select t.expect_error($q$insert into marketplace_reports (listing_id, reporter, reason)
  values ('a0000000-0000-4000-8000-000000000001', t.pid('ahmad.ramadhan@example.com'), 'other')$q$, 'marketplace_reports_one_per_reporter');
-- Bad reason, and a pending listing cannot be reported.
select t.expect_error($q$insert into marketplace_reports (listing_id, reporter, reason)
  values ('a0000000-0000-4000-8000-000000000002', t.pid('ahmad.ramadhan@example.com'), 'rude')$q$, 'reason');
select t.expect_error($q$insert into marketplace_reports (listing_id, reporter, reason)
  values ('a0000000-0000-4000-8000-000000000011', t.pid('ahmad.ramadhan@example.com'), 'spam')$q$, 'row-level security');
-- Reports are not readable directly; counts are admin-only.
select t.expect_error('select * from marketplace_reports', 'permission denied');
select t.expect_error(format($q$select * from marketplace_report_counts(%L, t.k())$q$, t.pid('bunga.ayu@example.com')), 'not_admin');
select t.assert((select report_count from marketplace_report_counts(t.pid('demo.admin@example.com'), t.k()) where listing_id = 'a0000000-0000-4000-8000-000000000001') = 2, 'admin sees 2 reports on listing 1');
-- Seller deletes own listing: its reports cascade away.
select marketplace_delete_listing(t.pid('bunga.ayu@example.com'), 'a0000000-0000-4000-8000-000000000001');
select t.assert((select count(*) from marketplace_report_counts(t.pid('demo.admin@example.com'), t.k())) = 0, 'reports cascade on listing delete');
reset role;

-- Storage bucket + policies exist.
select t.assert((select public and file_size_limit = 2097152 from storage.buckets where id = 'marketplace'), 'marketplace bucket public, 2 MB');
select t.assert((select count(*) from pg_policies where schemaname = 'storage' and policyname = 'marketplace_public_upload') = 1, 'bucket upload policy present');
select t.assert((select count(*) from pg_policies where schemaname = 'storage' and policyname = 'marketplace_public_read') = 0, 'bucket has no list policy (audit SA-20)');

\o
\echo 'marketplace_rls_test.sql: all assertions passed'
