-- Stage 6C: admins without a passphrase. Admins are rows in app_admins that
-- the owner fills from the dashboard. All app calls run as the anon role.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com', 'clara.putri@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

-- Fixtures: a pending business (ahmad), an approved one (siti) with a product, a pending legacy listing.
with x as (insert into businesses (owner_id, name, description, category, social_link, requested_band, status)
  values (jt.pid('ahmad.ramadhan@example.com'), 'Kopi Ahmad', 'Kopi', 'Food & Drink', 'https://instagram.com/kopi_ahmad', 'small', 'pending') returning id)
insert into t_ids select 'b_pending', id from x;
with x as (insert into businesses (owner_id, name, description, category, social_link, requested_band, approved_band, status, unlimited_until)
  values (jt.pid('siti.azizah@example.com'), 'Siti Catering', 'Catering', 'Services', 'https://instagram.com/siti_catering', 'medium', 'medium', 'approved', current_date + 10) returning id)
insert into t_ids select 'b_approved', id from x;
with x as (insert into marketplace_listings (seller_id, business_id, title, description, price_idr, category, city, image_url, contact_info, status, approved_at)
  values (jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_approved'), 'Nasi Kotak', 'enak', 1000, 'Food & Drink', 'Semarang', 'https://x.example/a.png', 'wa', 'approved', now()) returning id)
insert into t_ids select 'prod', id from x;
with x as (insert into marketplace_listings (seller_id, title, description, price_idr, category, city, image_url, contact_info, status)
  values (jt.pid('bagas.prasetyo@example.com'), 'Legacy pending', 'x', 1000, 'Other', 'Semarang', 'https://x.example/a.png', 'wa', 'pending') returning id)
insert into t_ids select 'legacy_pending', id from x;

-- Old passphrase setup (as the owner): clara has the OLD key, but is not in app_admins.
insert into marketplace_admins (profile_id) values (jt.pid('clara.putri@example.com')) on conflict do nothing;
select marketplace_set_admin_key(jt.pid('clara.putri@example.com'), 'old-shared-passphrase-1234');

set role anon;

-- The app cannot touch the admin lists at all.
select jt.expect_error($q$select * from app_admins$q$, 'permission denied');
select jt.expect_error(format($q$insert into app_admins (profile_id) values (%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'permission denied');
select jt.expect_error($q$update app_admins set note = 'x'$q$, 'permission denied');
select jt.expect_error($q$delete from app_admins$q$, 'permission denied');
select jt.expect_error($q$select * from marketplace_admins$q$, 'permission denied');
-- ... and cannot call the internal checks or set passphrases.
select jt.expect_error(format($q$select marketplace_set_admin_key(%L, 'another-passphrase-12345')$q$, jt.pid('ahmad.ramadhan@example.com')), 'permission denied');

-- Nobody is admin yet.
select jt.assert(is_app_admin(jt.pid('siti.azizah@example.com')) = false, 'siti is not admin');
select jt.assert(is_app_admin(gen_random_uuid()) = false, 'random id is not admin');
select jt.assert(is_app_admin(null) = false, 'null is not admin');
select jt.assert(marketplace_is_admin(jt.pid('clara.putri@example.com')) = false, 'old admin table no longer grants admin');

-- A non-admin id is rejected on EVERY admin function.
select jt.expect_error(format($q$select * from marketplace_admin_pending(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
select jt.expect_error(format($q$select marketplace_review_listing(%L, %L, 'approved', null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'legacy_pending')), 'not_admin');
select jt.expect_error(format($q$select * from marketplace_report_counts(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
select jt.expect_error(format($q$select * from admin_businesses_list(%L, null)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
select jt.expect_error(format($q$select admin_business_decide(%L, %L, 'approve', 'small', null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_pending')), 'not_admin');

-- The OLD passphrase no longer works: clara has the right key but is not in app_admins.
select jt.expect_error(format($q$select * from marketplace_admin_pending(%L, 'old-shared-passphrase-1234')$q$, jt.pid('clara.putri@example.com')), 'not_admin');
select jt.expect_error(format($q$select * from marketplace_report_counts(%L, 'old-shared-passphrase-1234')$q$, jt.pid('clara.putri@example.com')), 'not_admin');
select jt.expect_error(format($q$select marketplace_review_listing(%L, %L, 'approved', null, 'old-shared-passphrase-1234')$q$, jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'legacy_pending')), 'not_admin');
reset role;

-- The owner adds an admin from the dashboard (this is the SQL the PR gives).
insert into app_admins (profile_id, note)
select id, 'Gilang' from alumni_profiles where email = 'siti.azizah@example.com'
on conflict (profile_id) do nothing;
-- Adding twice changes nothing.
insert into app_admins (profile_id, note)
select id, 'again' from alumni_profiles where email = 'siti.azizah@example.com'
on conflict (profile_id) do nothing;
select jt.assert((select count(*) from app_admins) = 1, 'one admin row');

set role anon;
select jt.assert(is_app_admin(jt.pid('siti.azizah@example.com')) = true, 'siti is admin now');
select jt.assert(is_app_admin(jt.pid('ahmad.ramadhan@example.com')) = false, 'ahmad still not');
-- No passphrase needed.
select jt.assert((select count(*) from marketplace_admin_pending(jt.pid('siti.azizah@example.com')) where id = (select v from t_ids where k = 'legacy_pending')) = 1, 'admin sees the pending legacy listing, no passphrase');
-- Any passphrase value is simply ignored (it does not matter and cannot hurt).
select jt.assert((select count(*) from marketplace_admin_pending(jt.pid('siti.azizah@example.com'), 'whatever') where id = (select v from t_ids where k = 'legacy_pending')) = 1, 'passphrase argument is ignored');

-- Listings: approve a pending one, reject a live product (hide), approve it back.
select jt.assert((select status from marketplace_review_listing(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'legacy_pending'), 'approved', null)) = 'approved', 'admin approves');
select jt.assert((select status from marketplace_review_listing(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'prod'), 'rejected', 'Foto tidak sesuai')) = 'rejected', 'admin can reject an approved product');
select jt.assert((select count(*) from marketplace_listings where id = (select v from t_ids where k = 'prod')) = 0, 'rejected product is gone from the public list');
select jt.expect_error(format($q$select marketplace_review_listing(%L, %L, 'rejected', null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'prod')), 'reason_required|invalid_state');

-- Businesses: list (pending first).
select jt.assert((select count(*) from admin_businesses_list(jt.pid('siti.azizah@example.com'), null)) = 2, 'admin sees all businesses');
select jt.assert((select status from admin_businesses_list(jt.pid('siti.azizah@example.com'), null) limit 1) = 'pending', 'pending first');
select jt.assert((select count(*) from admin_businesses_list(jt.pid('siti.azizah@example.com'), 'approved')) = 1, 'filter by status');
-- Decisions.
select jt.expect_error(format($q$select admin_business_decide(%L, %L, 'approve', 'huge', null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_pending')), 'invalid_band');
select jt.expect_error(format($q$select admin_business_decide(%L, %L, 'approve', null, null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_pending')), 'invalid_band');
select jt.expect_error(format($q$select admin_business_decide(%L, %L, 'reject', null, '  ')$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_pending')), 'reason_required');
select jt.expect_error(format($q$select admin_business_decide(%L, %L, 'explode', null, null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_pending')), 'invalid_action');
select jt.expect_error(format($q$select admin_business_decide(%L, gen_random_uuid(), 'approve', 'micro', null)$q$, jt.pid('siti.azizah@example.com')), 'not_found');
select jt.expect_error(format($q$select admin_business_decide(%L, %L, 'suspend', null, 'x')$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_pending')), 'invalid_state');
select jt.expect_error(format($q$select admin_business_decide(%L, %L, 'restore', null, null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_pending')), 'invalid_state');
-- Reject, then the owner can fix it, then approve with a band the admin chooses.
select jt.assert((select status from admin_business_decide(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_pending'), 'reject', null, 'Link tidak bisa dibuka')) = 'rejected', 'rejected');
select jt.assert((select rejection_reason from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b_pending')) = 'Link tidak bisa dibuka', 'owner sees the reason');
select business_update(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b_pending'), 'Kopi Ahmad', 'Kopi', 'Food & Drink', 'https://instagram.com/kopi_ahmad', 'https://kopiahmad.example.com');
-- Requested band was 'small', the admin approves 'micro': the admin decides.
select jt.assert((select approved_band from admin_business_decide(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_pending'), 'approve', 'micro', null)) = 'micro', 'approved with the admin band');
select jt.assert((select count(*) from business_directory(jt.pid('ahmad.ramadhan@example.com'))) = 2, 'both approved businesses are in the directory');
-- Suspend hides products, restore brings them back.
select admin_business_decide(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_approved'), 'suspend', null, 'Laporan penipuan');
select jt.assert((select count(*) from business_directory(jt.pid('ahmad.ramadhan@example.com'))) = 1, 'suspended business leaves the directory');
select jt.assert((select rejection_reason from business_my(jt.pid('siti.azizah@example.com')) where id = (select v from t_ids where k = 'b_approved')) = 'Laporan penipuan', 'owner sees the suspension reason');
select admin_business_decide(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b_approved'), 'restore', null, null);
select jt.assert((select count(*) from business_directory(jt.pid('ahmad.ramadhan@example.com'))) = 2, 'restored');
select jt.assert((select rejection_reason from business_my(jt.pid('siti.azizah@example.com')) where id = (select v from t_ids where k = 'b_approved')) is null, 'reason cleared on restore');
reset role;

-- unlimited_until stays dashboard only: no admin function touches it.
select jt.assert((select unlimited_until from businesses where id = (select v from t_ids where k = 'b_approved')) = current_date + 10, 'unlimited_until untouched by admin actions');
select jt.assert((select reviewed_by from businesses where id = (select v from t_ids where k = 'b_pending')) = jt.pid('siti.azizah@example.com'), 'reviewer recorded');

rollback;
\o
\echo app admin checks passed
