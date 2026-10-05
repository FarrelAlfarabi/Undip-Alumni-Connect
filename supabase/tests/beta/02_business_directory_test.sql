-- Stage 5: business directory. All app calls run as the anon role.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com');
update alumni_profiles set verification_status = 'unverified' where email = 'rizky.yusuf@example.com';

-- Link cleaning.
select jt.assert(public.normalize_link('HTTPS://www.Instagram.com/Ahmad_Shop/?hl=id#top') = 'instagram.com/ahmad_shop', 'normalize_link cleans scheme, www, case, query, fragment');
select jt.assert(public.normalize_link('http://shop.example.com/') = 'shop.example.com', 'trailing slash removed');
select jt.assert(public.normalize_link('   ') is null, 'blank link is null');

set role anon;

-- No direct table access at all for the app.
select jt.expect_error($q$select * from businesses$q$, 'permission denied');
select jt.expect_error(format($q$insert into businesses (owner_id, name, description, category, social_link, requested_band, status) values (%L, 'Evil', 'x', 'Other', 'https://instagram.com/evil', 'micro', 'approved')$q$, jt.pid('ahmad.ramadhan@example.com')), 'permission denied');
select jt.expect_error($q$update businesses set status = 'approved'$q$, 'permission denied');

-- Register.
create temp table t_ids (k text primary key, v uuid);
insert into t_ids select 'b1', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Kopi Ahmad', 'Kopi dari Semarang', 'Food & Drink', 'https://www.instagram.com/kopi_ahmad/', null, 'small');
select jt.assert((select status from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')) = 'pending', 'new business is pending');

-- Owner must be a verified alumnus.
select jt.expect_error(format($q$select business_register(%L, 'Nama', 'desc', 'Other', 'https://instagram.com/x1', null, 'micro')$q$, jt.pid('rizky.yusuf@example.com')), 'not_verified');
select jt.expect_error($q$select business_register(gen_random_uuid(), 'Nama', 'desc', 'Other', 'https://instagram.com/x1', null, 'micro')$q$, 'not_verified');

-- Link rules.
select jt.expect_error(format($q$select business_register(%L, 'Nama', 'desc', 'Other', null, null, 'micro')$q$, jt.pid('siti.azizah@example.com')), 'link_required');
select jt.expect_error(format($q$select business_register(%L, 'Nama', 'desc', 'Other', 'javascript:alert(1)', null, 'micro')$q$, jt.pid('siti.azizah@example.com')), 'invalid_link');
select jt.expect_error(format($q$select business_register(%L, 'Nama', 'desc', 'Other', 'instagram', null, 'micro')$q$, jt.pid('siti.azizah@example.com')), 'invalid_link');
-- Same link in another form, same column and across columns.
select jt.expect_error(format($q$select business_register(%L, 'Tiruan', 'desc', 'Other', 'HTTP://instagram.com/Kopi_Ahmad?hl=en', null, 'micro')$q$, jt.pid('siti.azizah@example.com')), 'link_in_use');
select jt.expect_error(format($q$select business_register(%L, 'Tiruan', 'desc', 'Other', null, 'https://instagram.com/kopi_ahmad/', 'micro')$q$, jt.pid('siti.azizah@example.com')), 'link_in_use');
-- Bad band, category, empty name.
select jt.expect_error(format($q$select business_register(%L, 'Nama', 'desc', 'Other', 'https://instagram.com/x2', null, 'huge')$q$, jt.pid('siti.azizah@example.com')), 'invalid_band');
select jt.expect_error(format($q$select business_register(%L, 'Nama', 'desc', 'Spaceships', 'https://instagram.com/x3', null, 'micro')$q$, jt.pid('siti.azizah@example.com')), 'invalid_category');
select jt.expect_error(format($q$select business_register(%L, '  ', 'desc', 'Other', 'https://instagram.com/x4', null, 'micro')$q$, jt.pid('siti.azizah@example.com')), 'invalid_input');

-- One owner may register several businesses (each has its own link).
insert into t_ids select 'b2', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Batik Ahmad', 'Batik', 'Fashion', null, 'https://batikahmad.example.com', 'micro');
insert into t_ids select 's1', id from business_register(jt.pid('siti.azizah@example.com'), 'Siti Catering', 'Catering', 'Food & Drink', 'https://instagram.com/siti_catering', null, 'medium');

-- The owner sees their own, with status. Others do not see them.
select jt.assert(jt.count_of(format($q$select 1 from business_my(%L)$q$, jt.pid('ahmad.ramadhan@example.com'))) = 2, 'owner sees both own businesses');
select jt.assert(jt.count_of(format($q$select 1 from business_my(%L)$q$, jt.pid('siti.azizah@example.com'))) = 1, 'other owner sees only theirs');

-- Pending businesses are invisible in the directory.
select jt.assert(jt.count_of(format($q$select 1 from business_directory(%L)$q$, jt.pid('siti.azizah@example.com'))) = 0, 'pending not in the directory');
select jt.expect_error(format($q$select * from business_directory(%L)$q$, jt.pid('rizky.yusuf@example.com')), 'not_verified');

-- Owner edits while pending.
select business_update(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), 'Kopi Ahmad Baru', 'Deskripsi baru', 'Food & Drink', 'https://instagram.com/kopi_ahmad', 'https://kopiahmad.example.com');
select jt.expect_error(format($q$select business_update(%L, %L, 'x1', 'd', 'Other', 'https://instagram.com/q', null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b1')), 'not_owner');
select jt.expect_error(format($q$select business_update(%L, gen_random_uuid(), 'x1', 'd', 'Other', 'https://instagram.com/q', null)$q$, jt.pid('siti.azizah@example.com')), 'not_found');
-- The band cannot be changed by the owner: no function takes it.
select jt.assert((select requested_band from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')) = 'small', 'requested band unchanged after edit');

reset role;

-- Dashboard (postgres) approves b1 and rejects b2.
update businesses set status = 'approved', approved_band = 'small' where id = (select v from t_ids where k = 'b1');
update businesses set status = 'rejected', rejection_reason = 'Link tidak bisa dibuka' where id = (select v from t_ids where k = 'b2');

set role anon;
select jt.assert((select count(*) from business_directory(jt.pid('siti.azizah@example.com'))) = 1, 'approved business is in the directory');
select jt.assert((select name from business_directory(jt.pid('siti.azizah@example.com')) limit 1) = 'Kopi Ahmad Baru', 'directory shows the edited name');
select jt.assert((select rejection_reason from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b2')) = 'Link tidak bisa dibuka', 'owner sees the rejection reason');

-- Approved business is locked for the owner. Rejected can be fixed and re-applied.
select jt.expect_error(format($q$select business_update(%L, %L, 'x1', 'd', 'Other', 'https://instagram.com/q', null)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'locked');
select business_update(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b2'), 'Batik Ahmad', 'Batik tulis', 'Fashion', null, 'https://batikahmad.example.com/toko');
select jt.assert((select status from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b2')) = 'pending', 'rejected business goes back to pending after edit');
select jt.assert((select rejection_reason from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b2')) is null, 'rejection reason cleared');
select jt.assert((select approved_band from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b2')) is null, 'approved band still empty');
reset role;

-- Defense in depth: with no policy, RLS already hides every row from anon, so
-- a stray UPDATE changes nothing.
grant select, insert, update on businesses to anon;
set role anon;
update businesses set status = 'approved';
select jt.assert(jt.count_of($q$select 1 from businesses$q$) = 0, 'RLS hides every row from anon');
reset role;
-- And even if someone added a table grant AND a permissive policy by mistake,
-- the column lock trigger still stops self-approval.
create policy tmp_open on businesses for all to anon using (true) with check (true);
set role anon;
select jt.expect_error(format($q$update businesses set status = 'approved' where id = %L$q$, (select v from t_ids where k = 's1')), 'locked_column');
select jt.expect_error(format($q$update businesses set approved_band = 'micro' where id = %L$q$, (select v from t_ids where k = 's1')), 'locked_column');
select jt.expect_error(format($q$update businesses set unlimited_until = current_date + 365 where id = %L$q$, (select v from t_ids where k = 's1')), 'locked_column');
select jt.expect_error(format($q$update businesses set requested_band = 'micro' where id = %L$q$, (select v from t_ids where k = 's1')), 'locked_column');
select jt.expect_error(format($q$update businesses set owner_id = %L where id = %L$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 's1')), 'locked_column');
select jt.expect_error(format($q$insert into businesses (owner_id, name, description, category, social_link, requested_band, status) values (%L, 'Evil', 'x', 'Other', 'https://instagram.com/evil', 'micro', 'approved')$q$, jt.pid('ahmad.ramadhan@example.com')), 'locked_column');
select jt.expect_error(format($q$insert into businesses (owner_id, name, description, category, social_link, requested_band, unlimited_until) values (%L, 'Evil', 'x', 'Other', 'https://instagram.com/evil2', 'micro', current_date + 99)$q$, jt.pid('ahmad.ramadhan@example.com')), 'locked_column');
reset role;
drop policy tmp_open on businesses;
revoke all on businesses from anon;

-- Dashboard stays unrestricted.
update businesses set status = 'suspended', unlimited_until = current_date + 30 where id = (select v from t_ids where k = 's1');
select jt.assert((select unlimited_until from businesses where id = (select v from t_ids where k = 's1')) = current_date + 30, 'dashboard can set unlimited_until');

rollback;
\o
\echo business directory checks passed
