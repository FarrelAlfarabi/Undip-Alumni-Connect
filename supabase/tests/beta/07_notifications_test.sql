-- Stage 6E: notifications are created only by the database. All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com', 'clara.putri@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

-- Two admins: clara and bagas.
insert into app_admins (profile_id, note) values (jt.pid('clara.putri@example.com'), 'A'), (jt.pid('bagas.prasetyo@example.com'), 'B');

create function jt.n(p_recipient text, p_type text) returns bigint language sql stable as $$
  select count(*) from notifications where recipient_id = jt.pid(p_recipient) and type = p_type $$;
create function jt.total() returns bigint language sql stable as $$ select count(*) from notifications $$;

-- The app cannot create, delete or rewrite notifications.
set role anon;
select jt.expect_error(format($q$insert into notifications (recipient_id, title, body) values (%L, 'x', 'y')$q$, jt.pid('ahmad.ramadhan@example.com')), 'permission denied');
select jt.expect_error($q$delete from notifications$q$, 'permission denied');
select jt.expect_error($q$update notifications set title = 'hacked'$q$, 'permission denied');
select jt.expect_error(format($q$select notify_create(%L, null, 'x', 't', 'b', null, null, 'k')$q$, jt.pid('ahmad.ramadhan@example.com')), 'permission denied');
reset role;

-- ---------------------------------------------------------- contact requests ---
set role anon;
insert into t_ids select 'req', id from contact_request_send(jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com'), 'Halo');
reset role;
select jt.assert(jt.n('siti.azizah@example.com', 'contact_request_received') = 1, 'target gets exactly one notification');
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'contact_request_received') = 0, 'requester gets none (own action)');
select jt.assert((select target_type || ':' || (target_id = (select v from t_ids where k = 'req'))::text from notifications where type = 'contact_request_received') = 'contact_request:true', 'points at the request');

set role anon;
select contact_request_respond(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'req'), true, 'WA 0812');
reset role;
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'contact_request_accepted') = 1, 'requester told about accept');
select jt.assert(jt.n('siti.azizah@example.com', 'contact_request_accepted') = 0, 'target not told about own action');

-- A rejection creates no notification.
set role anon;
select contact_request_send(jt.pid('ahmad.ramadhan@example.com'), jt.pid('bagas.prasetyo@example.com'), null);
reset role;
select jt.assert(jt.n('bagas.prasetyo@example.com', 'contact_request_received') = 1, 'bagas got the request notification');
insert into t_ids select 'req2', id from contact_requests where requester_id = jt.pid('ahmad.ramadhan@example.com') and target_id = jt.pid('bagas.prasetyo@example.com');
set role anon;
select contact_request_respond(jt.pid('bagas.prasetyo@example.com'), (select v from t_ids where k = 'req2'), false, null);
reset role;
select jt.assert((select count(*) from notifications where type = 'contact_request_accepted') = 1, 'a rejection creates nothing');
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'contact_request_rejected') = 0, 'no rejected type exists');

-- ------------------------------------------------------------- businesses ---
set role anon;
insert into t_ids select 'biz', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Kopi Ahmad', 'Kopi', 'Food & Drink', 'https://instagram.com/kopi_ahmad', null, 'small');
reset role;
select jt.assert(jt.n('clara.putri@example.com', 'business_pending') = 1 and jt.n('bagas.prasetyo@example.com', 'business_pending') = 1, 'every admin gets one pending-business notification');
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'business_pending') = 0, 'owner gets none');

set role anon;
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'biz'), 'reject', null, 'Link rusak');
reset role;
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'business_rejected') = 1, 'owner told about rejection');
select jt.assert((select body from notifications where type = 'business_rejected') like '%Reason: Link rusak%', 'rejection carries the reason');

set role anon;
select business_update(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'biz'), 'Kopi Ahmad', 'Kopi', 'Food & Drink', 'https://instagram.com/kopi_ahmad', 'https://kopiahmad.example.com');
reset role;
select jt.assert(jt.n('clara.putri@example.com', 'business_pending') = 2, 'applying again notifies the admins again (a new event)');

set role anon;
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'biz'), 'approve', 'micro', null);
reset role;
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'business_approved') = 1, 'owner told about approval');
set role anon;
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'biz'), 'suspend', null, 'Laporan');
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'biz'), 'restore', null, null);
reset role;
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'business_suspended') = 1, 'owner told about suspension');
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'business_restored') = 1, 'owner told about restore');
select jt.assert((select body from notifications where type = 'business_suspended') like '%Reason: Laporan%', 'suspension carries the reason');
-- Dashboard edit that does not change the status: nothing new.
update businesses set description = 'Kopi baru' where id = (select v from t_ids where k = 'biz');
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'business_approved') = 1, 'no duplicate on an unrelated edit');

-- Own action: an admin approving their own business is not notified.
with x as (insert into businesses (owner_id, name, description, category, social_link, requested_band, status)
  values (jt.pid('clara.putri@example.com'), 'Toko Clara', 'x', 'Other', 'https://instagram.com/toko_clara', 'micro', 'pending') returning id)
insert into t_ids select 'clara_biz', id from x;
select jt.assert(jt.n('clara.putri@example.com', 'business_pending') = 2, 'admin owner is not notified about own business (still 2)');
select jt.assert(jt.n('bagas.prasetyo@example.com', 'business_pending') = 3, 'the other admin is');
set role anon;
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'clara_biz'), 'approve', 'micro', null);
reset role;
select jt.assert(jt.n('clara.putri@example.com', 'business_approved') = 0, 'self-approval does not notify yourself');

-- ----------------------------------------------------------------- hiding ---
with x as (insert into job_posts (posted_by, title, company, description) values (jt.pid('ahmad.ramadhan@example.com'), 'Staff', 'PT', 'd') returning id)
insert into t_ids select 'job', id from x;
with x as (insert into marketplace_listings (seller_id, business_id, title, description, price_idr, category, city, image_url, contact_info, status, approved_at)
  values (jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'biz'), 'Kopi Arabika', 'enak', 1000, 'Food & Drink', 'Semarang', 'https://x.example/a.png', 'wa', 'approved', now()) returning id)
insert into t_ids select 'prod', id from x;
set role anon;
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'job', (select v from t_ids where k = 'job'), 'hide', 'Palsu');
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'product', (select v from t_ids where k = 'prod'), 'hide', 'Foto curian');
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'business', (select v from t_ids where k = 'biz'), 'hide', 'Penipuan');
reset role;
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'content_hidden') = 3, 'owner told about each hidden thing');
select jt.assert((select count(*) from notifications where type = 'content_hidden' and body like '%Reason: Palsu%') = 1, 'job reason');
select jt.assert((select count(*) from notifications where type = 'content_hidden' and body like '%Reason: Foto curian%') = 1, 'product reason');
select jt.assert((select count(*) from notifications where type = 'content_hidden' and body like '%Reason: Penipuan%') = 1, 'business reason');
-- Restore and hide again is a new event; hiding twice in a row is not.
set role anon;
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'job', (select v from t_ids where k = 'job'), 'hide', 'Palsu lagi');
reset role;
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'content_hidden') = 3, 'hiding something already hidden creates nothing');
set role anon;
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'job', (select v from t_ids where k = 'job'), 'restore', null);
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'job', (select v from t_ids where k = 'job'), 'hide', 'Palsu 3');
reset role;
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'content_hidden') = 4, 'hide after restore is a new event');
set role anon;
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'business', (select v from t_ids where k = 'biz'), 'restore', null);
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'job', (select v from t_ids where k = 'job'), 'restore', null);
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'product', (select v from t_ids where k = 'prod'), 'restore', null);
reset role;

-- ---------------------------------------------------------------- reports ---
set role anon;
select content_report_create(jt.pid('siti.azizah@example.com'), 'job', (select v from t_ids where k = 'job'), 'spam_or_scam', null);
insert into marketplace_reports (listing_id, reporter, reason) values ((select v from t_ids where k = 'prod'), jt.pid('siti.azizah@example.com'), 'spam');
reset role;
select jt.assert(jt.n('clara.putri@example.com', 'report_new') = 2 and jt.n('bagas.prasetyo@example.com', 'report_new') = 2, 'every admin gets one notification per new report (content and marketplace)');
select jt.assert(jt.n('siti.azizah@example.com', 'report_new') = 0 and jt.n('ahmad.ramadhan@example.com', 'report_new') = 0, 'non-admins get none');
-- An admin who blocked the reporter is not told.
set role anon;
select user_block(jt.pid('clara.putri@example.com'), jt.pid('siti.azizah@example.com'));
select content_report_create(jt.pid('siti.azizah@example.com'), 'business', (select v from t_ids where k = 'biz'), 'other', null);
reset role;
select jt.assert(jt.n('clara.putri@example.com', 'report_new') = 2, 'blocker admin is not notified by the blocked reporter');
select jt.assert(jt.n('bagas.prasetyo@example.com', 'report_new') = 3, 'the other admin is');
-- An admin who reports is not told about their own report.
set role anon;
select content_report_create(jt.pid('clara.putri@example.com'), 'profile', jt.pid('ahmad.ramadhan@example.com'), 'other', null);
reset role;
select jt.assert(jt.n('clara.putri@example.com', 'report_new') = 2, 'admin reporter is not told about their own report');

-- ------------------------------------------------------- job applications ---
set role anon;
insert into job_applications (job_post_id, applicant_id, full_name, email) values ((select v from t_ids where k = 'job'), jt.pid('siti.azizah@example.com'), 'Siti', 's@example.com');
reset role;
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'job_application') = 1, 'poster told once about the application');
select jt.assert((select job_post_id from notifications where type = 'job_application') = (select v from t_ids where k = 'job'), 'job_post_id kept for the old screen');
select jt.assert((select count(*) from email_log where recipient_email = 'ahmad.ramadhan@example.com') = 1, 'simulated email still logged');
-- Own application: nothing. A blocked applicant: nothing.
set role anon;
insert into job_applications (job_post_id, applicant_id, full_name, email) values ((select v from t_ids where k = 'job'), jt.pid('ahmad.ramadhan@example.com'), 'Ahmad', 'a@example.com');
select user_block(jt.pid('ahmad.ramadhan@example.com'), jt.pid('bagas.prasetyo@example.com'));
insert into job_applications (job_post_id, applicant_id, full_name, email) values ((select v from t_ids where k = 'job'), jt.pid('bagas.prasetyo@example.com'), 'Bagas', 'b@example.com');
reset role;
select jt.assert(jt.n('ahmad.ramadhan@example.com', 'job_application') = 1, 'no notification for own application or a blocked applicant');
select jt.assert((select count(*) from email_log where recipient_email = 'ahmad.ramadhan@example.com') = 1, 'no simulated email either');

-- ----------------------------------------------------------------- dedupe ---
select jt.assert(notify_create(jt.pid('ahmad.ramadhan@example.com'), null, 'test', 't', 'b', null, null, 'same-key') = true, 'first call creates');
select jt.assert(notify_create(jt.pid('ahmad.ramadhan@example.com'), null, 'test', 't', 'b', null, null, 'same-key') = false, 'same key again creates nothing');
select jt.assert((select count(*) from notifications where event_key = 'same-key') = 1, 'one row');

-- ------------------------------------------------ the app can mark as read ---
-- Not by a direct UPDATE any more (see 11_close_anon_reads_test.sql), but through the function.
set role anon;
select notifications_mark_read(jt.pid('ahmad.ramadhan@example.com'));
reset role;
select jt.assert((select count(*) from notifications where recipient_id = jt.pid('ahmad.ramadhan@example.com') and read_at is null) = 0, 'read_at can be set');

rollback;
\o
\echo notification checks passed
