-- Account deactivation: hides the person, removes nothing. All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com');
update alumni_profiles set verification_status = 'unverified' where email = 'rizky.yusuf@example.com';

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

-- Ahmad owns one approved business with one approved product.
set role anon;
insert into t_ids select 'biz', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Kopi Ahmad', 'Kopi', 'Food & Drink', 'https://www.instagram.com/kopi_ahmad/', null, 'small');
reset role;
update businesses set status = 'approved', approved_band = 'small' where id = (select v from t_ids where k = 'biz');
insert into marketplace_listings (seller_id, business_id, title, description, price_idr, category, city, image_url, contact_info, status)
  values (jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'biz'), 'Kopi', 'd', 1, 'Other', 'x', 'https://x.example/a.png', 'wa', 'approved');

-- Everything is visible while active.
set role anon;
select jt.assert(jt.count_of($q$select 1 from alumni_profiles where email = 'ahmad.ramadhan@example.com'$q$) = 1, 'active: profile visible');
select jt.assert(jt.count_of(format($q$select 1 from business_directory(%L)$q$, jt.pid('siti.azizah@example.com'))) = 1, 'active: business listed');
select jt.assert(jt.count_of($q$select 1 from marketplace_listings where title = 'Kopi'$q$) = 1, 'active: product listed');

-- The app cannot write the column directly.
select jt.expect_error(format($q$update alumni_profiles set deactivated_at = now() where id = %L$q$, jt.pid('ahmad.ramadhan@example.com')), 'can be updated');

-- Only verified, existing people can deactivate.
select jt.expect_error(format($q$select account_deactivate(%L)$q$, jt.pid('rizky.yusuf@example.com')), 'not_verified');
select jt.expect_error($q$select account_deactivate(gen_random_uuid())$q$, 'not_verified');

-- Deactivate.
select account_deactivate(jt.pid('ahmad.ramadhan@example.com'));
select account_deactivate(jt.pid('ahmad.ramadhan@example.com'));  -- twice is fine
select jt.assert((select deactivated_at from alumni_profiles where id = jt.pid('ahmad.ramadhan@example.com')) is not null, 'deactivated_at set');
-- Business and product are hidden; the business directory still works for others.
select jt.assert(jt.count_of(format($q$select 1 from business_directory(%L)$q$, jt.pid('siti.azizah@example.com'))) = 0, 'deactivated: business hidden');
select jt.assert(jt.count_of($q$select 1 from marketplace_listings where title = 'Kopi'$q$) = 0, 'deactivated: product hidden');
-- Before real login the profile row stays readable (the app filters it), so the
-- person can find it again to come back.
select jt.assert(jt.count_of($q$select 1 from alumni_profiles where email = 'ahmad.ramadhan@example.com'$q$) = 1, 'login off: row still readable');
reset role;

-- Nothing was removed.
select jt.assert((select count(*) from businesses where id = (select v from t_ids where k = 'biz')) = 1, 'business kept');
select jt.assert((select count(*) from marketplace_listings where title = 'Kopi') = 1, 'product kept');
select jt.assert((select deleted_at from alumni_profiles where id = jt.pid('ahmad.ramadhan@example.com')) is null, 'not deleted');

-- With real login ON the row itself is hidden from other people.
update app_settings set value = 'on' where key = 'require_login';
set role anon;
select jt.assert(jt.count_of($q$select 1 from alumni_profiles where email = 'ahmad.ramadhan@example.com'$q$) = 0, 'login on: deactivated row hidden');
select jt.assert(jt.count_of($q$select 1 from alumni_profiles where email = 'siti.azizah@example.com'$q$) = 1, 'login on: others still visible');
reset role;
update app_settings set value = 'off' where key = 'require_login';

-- Reactivate: everything is back.
set role anon;
select account_reactivate(jt.pid('ahmad.ramadhan@example.com'));
select jt.assert((select deactivated_at from alumni_profiles where id = jt.pid('ahmad.ramadhan@example.com')) is null, 'reactivated');
select jt.assert(jt.count_of(format($q$select 1 from business_directory(%L)$q$, jt.pid('siti.azizah@example.com'))) = 1, 'reactivated: business back');
select jt.assert(jt.count_of($q$select 1 from marketplace_listings where title = 'Kopi'$q$) = 1, 'reactivated: product back');
select jt.expect_error($q$select account_reactivate(gen_random_uuid())$q$, 'not_found');
reset role;

-- ---- real login ON: people can only act on themselves ---------------------
alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;
insert into t_ids select 'ua', gen_random_uuid();
insert into t_ids select 'us', gen_random_uuid();
insert into auth.users (id, email) values
  ((select v from t_ids where k = 'ua'), 'ahmad.ramadhan@example.com'),
  ((select v from t_ids where k = 'us'), 'siti.azizah@example.com');
update alumni_profiles set user_id = (select v from t_ids where k = 'ua') where email = 'ahmad.ramadhan@example.com';
update alumni_profiles set user_id = (select v from t_ids where k = 'us') where email = 'siti.azizah@example.com';
grant all on t_ids to authenticated;
update app_settings set value = 'on' where key = 'require_login';

-- Siti cannot deactivate or reactivate Ahmad, and the directory still checks the caller.
select set_config('test.uid', (select v::text from t_ids where k = 'us'), true);
set role authenticated;
select jt.expect_error(format($q$select account_deactivate(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
select jt.expect_error(format($q$select account_reactivate(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
select jt.expect_error(format($q$select * from business_directory(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
select jt.assert(jt.count_of(format($q$select 1 from business_directory(%L)$q$, jt.pid('siti.azizah@example.com'))) = 1, 'login on: Siti sees the directory');
reset role;

-- Ahmad deactivates himself: others stop seeing the row; he still sees it.
select set_config('test.uid', (select v::text from t_ids where k = 'ua'), true);
set role authenticated;
select account_deactivate(jt.pid('ahmad.ramadhan@example.com'));
select jt.assert(jt.count_of($q$select 1 from alumni_profiles where email = 'ahmad.ramadhan@example.com'$q$) = 1, 'login on: owner still sees own row');
reset role;
select jt.assert(not marketplace_business_visible((select v from t_ids where k = 'biz')), 'owner deactivated: business not visible for products');
select set_config('test.uid', (select v::text from t_ids where k = 'us'), true);
set role authenticated;
select jt.assert(jt.count_of($q$select 1 from alumni_profiles where email = 'ahmad.ramadhan@example.com'$q$) = 0, 'login on: others do not see the row');
reset role;
select set_config('test.uid', (select v::text from t_ids where k = 'ua'), true);
set role authenticated;
select account_reactivate(jt.pid('ahmad.ramadhan@example.com'));
reset role;
select jt.assert(marketplace_business_visible((select v from t_ids where k = 'biz')), 'reactivated: business visible again');
update app_settings set value = 'off' where key = 'require_login';

-- Documented on purpose: job posts and contact requests still show the name.

-- A deleted account cannot be deactivated or reactivated.
select account_delete(jt.pid('siti.azizah@example.com'));
set role anon;
select jt.expect_error(format($q$select account_reactivate(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_found');
reset role;

rollback;
\o
\echo account deactivation checks passed
