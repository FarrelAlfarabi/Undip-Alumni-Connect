-- Stage 6G: consent and account deletion. All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com', 'clara.putri@example.com');
update alumni_profiles set verification_status = 'unverified' where email = 'rizky.yusuf@example.com';
insert into app_admins (profile_id, note) values (jt.pid('ahmad.ramadhan@example.com'), 'admin who will leave'), (jt.pid('clara.putri@example.com'), 'stays');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

-- ---------------------------------------------------------------- consent ---
set role anon;
select jt.assert((select policy_version from alumni_profiles where id = jt.pid('siti.azizah@example.com')) is null, 'nobody has accepted yet');
-- The app cannot write the consent columns directly, or deleted_at.
select jt.expect_error(format($q$update alumni_profiles set policy_version = 'x' where id = %L$q$, jt.pid('siti.azizah@example.com')), 'can be updated');
select jt.expect_error(format($q$update alumni_profiles set policy_accepted_at = now() where id = %L$q$, jt.pid('siti.azizah@example.com')), 'can be updated');
select jt.expect_error(format($q$update alumni_profiles set deleted_at = now() where id = %L$q$, jt.pid('siti.azizah@example.com')), 'can be updated');
-- The fields the app edits still work.
update alumni_profiles set industry = 'Keuangan' where id = jt.pid('siti.azizah@example.com');
-- Through the function it works, for verified people only.
select account_accept_policy(jt.pid('siti.azizah@example.com'), '2026-10-03');
select jt.assert((select policy_version from alumni_profiles where id = jt.pid('siti.azizah@example.com')) = '2026-10-03', 'version saved');
select jt.assert((select policy_accepted_at from alumni_profiles where id = jt.pid('siti.azizah@example.com')) > now() - interval '1 minute', 'time saved');
select jt.expect_error(format($q$select account_accept_policy(%L, '2026-10-03')$q$, jt.pid('rizky.yusuf@example.com')), 'not_verified');
select jt.expect_error(format($q$select account_accept_policy(%L, '   ')$q$, jt.pid('siti.azizah@example.com')), 'invalid_version');
-- A newer version replaces the old one.
select account_accept_policy(jt.pid('siti.azizah@example.com'), '2026-12-01');
select jt.assert((select policy_version from alumni_profiles where id = jt.pid('siti.azizah@example.com')) = '2026-12-01', 'newer version saved');
reset role;

insert into t_ids select 'ahmad_id', id from alumni_profiles where email = 'ahmad.ramadhan@example.com';
-- ----------------------------------------------- data of the person who leaves ---
-- ahmad leaves. He has a business, a product, a job with an application from siti,
-- his own application, requests in both directions, notifications, blocks, feedback,
-- reports filed and received, a chat message, an email log row, and is an admin.
with x as (insert into businesses (owner_id, name, description, category, social_link, requested_band, approved_band, status)
  values (jt.pid('ahmad.ramadhan@example.com'), 'Kopi Ahmad', 'Kopi', 'Food & Drink', 'https://instagram.com/kopi_ahmad', 'micro', 'micro', 'approved') returning id)
insert into t_ids select 'biz', id from x;
with x as (insert into businesses (owner_id, name, description, category, social_link, requested_band, approved_band, status)
  values (jt.pid('siti.azizah@example.com'), 'Siti Catering', 'Catering', 'Services', 'https://instagram.com/siti_catering', 'small', 'small', 'approved') returning id)
insert into t_ids select 'siti_biz', id from x;
with x as (insert into marketplace_listings (seller_id, business_id, title, description, price_idr, category, city, image_url, contact_info, status, approved_at)
  values (jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'biz'), 'Kopi Arabika', 'enak', 1000, 'Food & Drink', 'Semarang', 'https://x.supabase.co/storage/v1/object/public/marketplace/AHMADID/foto1.png', 'wa', 'approved', now()) returning id)
insert into t_ids select 'prod', id from x;
with x as (insert into marketplace_listings (seller_id, business_id, title, description, price_idr, category, city, image_url, contact_info, status, approved_at)
  values (jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'siti_biz'), 'Nasi Kotak', 'enak', 1000, 'Food & Drink', 'Semarang', 'https://x.supabase.co/storage/v1/object/public/marketplace/SITIID/nasi.png', 'wa', 'approved', now()) returning id)
insert into t_ids select 'siti_prod', id from x;
with x as (insert into job_posts (posted_by, title, company, description) values (jt.pid('ahmad.ramadhan@example.com'), 'Staff', 'PT A', 'd') returning id)
insert into t_ids select 'job', id from x;
with x as (insert into job_posts (posted_by, title, company, description) values (jt.pid('siti.azizah@example.com'), 'Analis', 'PT B', 'd') returning id)
insert into t_ids select 'siti_job', id from x;
-- siti applied to ahmad's job (her application must go because the job goes), ahmad applied to siti's job (with a CV).
insert into job_applications (job_post_id, applicant_id, full_name, email, cv_path) values ((select v from t_ids where k = 'job'), jt.pid('siti.azizah@example.com'), 'Siti', 's@example.com', 'siti/cv.pdf');
insert into job_applications (job_post_id, applicant_id, full_name, email, phone, cv_path) values ((select v from t_ids where k = 'siti_job'), jt.pid('ahmad.ramadhan@example.com'), 'Ahmad', 'ahmad.ramadhan@example.com', '0812', 'ahmad/cv.pdf');
insert into contact_requests (requester_id, target_id, message) values (jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com'), 'dari ahmad');
insert into contact_requests (requester_id, target_id, message, status, shared_contact, responded_at) values (jt.pid('bagas.prasetyo@example.com'), jt.pid('ahmad.ramadhan@example.com'), 'ke ahmad', 'accepted', 'wa 0812', now());
insert into user_blocks values (jt.pid('ahmad.ramadhan@example.com'), jt.pid('bagas.prasetyo@example.com'));
insert into user_blocks values (jt.pid('clara.putri@example.com'), jt.pid('ahmad.ramadhan@example.com'));
insert into feedback_reports (profile_id, message) values (jt.pid('ahmad.ramadhan@example.com'), 'bug');
insert into feedback_reports (profile_id, message) values (jt.pid('siti.azizah@example.com'), 'siti bug');
-- Reports: ahmad reported siti's job (his note has personal text); siti reported ahmad's business.
insert into content_reports (reporter_id, target_type, target_id, reason, note) values (jt.pid('ahmad.ramadhan@example.com'), 'job', (select v from t_ids where k = 'siti_job'), 'other', 'hubungi saya 0812');
insert into content_reports (reporter_id, target_type, target_id, reason) values (jt.pid('siti.azizah@example.com'), 'business', (select v from t_ids where k = 'biz'), 'other');
insert into marketplace_reports (listing_id, reporter, reason, note) values ((select v from t_ids where k = 'siti_prod'), jt.pid('ahmad.ramadhan@example.com'), 'spam', 'catatan pribadi');
-- Chat (hidden in the app, data kept): a message by ahmad.
with x as (insert into conversations (participant_one, participant_two) values (jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com')) returning id)
insert into t_ids select 'conv', id from x;
insert into messages (conversation_id, sender_id, body) values ((select v from t_ids where k = 'conv'), jt.pid('ahmad.ramadhan@example.com'), 'hai');
insert into messages (conversation_id, sender_id, body) values ((select v from t_ids where k = 'conv'), jt.pid('siti.azizah@example.com'), 'halo');
insert into city_chat_messages (city, sender_id, body) values ('Semarang', jt.pid('ahmad.ramadhan@example.com'), 'halo kota');
update alumni_profiles set city = 'Semarang', current_employer = 'PT A', "current_role" = 'Manager', industry = 'Keuangan', company = 'PT A' where id = jt.pid('ahmad.ramadhan@example.com');
select jt.assert((select count(*) from notifications where recipient_id = jt.pid('ahmad.ramadhan@example.com') or actor_id = jt.pid('ahmad.ramadhan@example.com')) > 0, 'ahmad is part of some notifications');
select jt.assert((select count(*) from email_log where recipient_email = 'ahmad.ramadhan@example.com') >= 0, 'email log readable');
insert into email_log (recipient_email, subject, body) values ('ahmad.ramadhan@example.com', 's', 'b');

-- ----------------------------------------------------------- the file list ---
set role anon;
select jt.assert((select count(*) from account_files(jt.pid('ahmad.ramadhan@example.com')) where bucket = 'marketplace' and path = 'AHMADID/foto1.png') = 1, 'product photo path found');
select jt.assert((select count(*) from account_files(jt.pid('ahmad.ramadhan@example.com')) where bucket = 'cvs' and path = 'ahmad/cv.pdf') = 1, 'his own CV path found');
select jt.assert((select count(*) from account_files(jt.pid('ahmad.ramadhan@example.com')) where path like 'siti%') = 0, 'not other peoples files');

-- ------------------------------------------------------------- the deletion ---
select jt.expect_error(format($q$select account_delete(%L)$q$, gen_random_uuid()), 'not_found');
create temp table t_result (r jsonb);
grant all on t_result to anon;
insert into t_result select account_delete(jt.pid('ahmad.ramadhan@example.com'));
reset role;
select jt.assert((select (r ->> 'deleted')::boolean from t_result) = true, 'result says deleted');
select jt.assert((select jsonb_array_length(r -> 'files') from t_result) = 2, 'result lists the two files');
select jt.assert((select (r -> 'removed' ->> 'businesses')::int from t_result) = 1, 'result counts the business');

-- Gone: his own data.
select jt.assert((select count(*) from businesses where owner_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'businesses deleted');
select jt.assert((select count(*) from marketplace_listings where seller_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'products deleted');
select jt.assert((select count(*) from job_posts where posted_by = (select v from t_ids where k = 'ahmad_id')) = 0, 'jobs deleted');
select jt.assert((select count(*) from job_applications where applicant_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'his applications deleted');
select jt.assert((select count(*) from job_applications where job_post_id = (select v from t_ids where k = 'job')) = 0, 'applications to his job deleted with the job');
select jt.assert((select count(*) from contact_requests where requester_id = (select v from t_ids where k = 'ahmad_id') or target_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'requests in both directions deleted');
select jt.assert((select count(*) from user_blocks where blocker_id = (select v from t_ids where k = 'ahmad_id') or blocked_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'blocks in both directions deleted');
select jt.assert((select count(*) from notifications where recipient_id = (select v from t_ids where k = 'ahmad_id') or actor_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'notifications to and from deleted');
select jt.assert((select count(*) from feedback_reports where profile_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'his feedback deleted');
select jt.assert((select count(*) from email_log where recipient_email = 'ahmad.ramadhan@example.com') = 0, 'email log rows with his email deleted');
select jt.assert((select count(*) from messages where sender_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'his chat messages deleted');
select jt.assert((select count(*) from city_chat_messages where sender_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'his city chat messages deleted');
select jt.assert((select count(*) from app_admins where profile_id = (select v from t_ids where k = 'ahmad_id')) = 0, 'no longer an admin');

-- Stays: reports for moderation, without personal details; other people's data.
select jt.assert((select count(*) from content_reports where reporter_id = (select v from t_ids where k = 'ahmad_id')) = 1, 'report he filed stays');
select jt.assert((select note from content_reports where reporter_id = (select v from t_ids where k = 'ahmad_id')) is null, '... without his note');
select jt.assert((select count(*) from marketplace_reports where reporter = (select v from t_ids where k = 'ahmad_id')) = 1, 'marketplace report he filed stays');
select jt.assert((select note from marketplace_reports where reporter = (select v from t_ids where k = 'ahmad_id')) is null, '... without his note');
select jt.assert((select count(*) from content_reports where target_type = 'business' and target_id = (select v from t_ids where k = 'biz')) = 1, 'report against his business stays');
select jt.assert((select count(*) from businesses where owner_id = jt.pid('siti.azizah@example.com')) = 1, 'siti business untouched');
select jt.assert((select count(*) from marketplace_listings where seller_id = jt.pid('siti.azizah@example.com')) = 1, 'siti product untouched');
select jt.assert((select count(*) from job_posts where posted_by = jt.pid('siti.azizah@example.com')) = 1, 'siti job untouched');
select jt.assert((select count(*) from feedback_reports where profile_id = jt.pid('siti.azizah@example.com')) = 1, 'siti feedback untouched');
select jt.assert((select count(*) from messages where sender_id = jt.pid('siti.azizah@example.com')) = 1, 'siti chat message untouched');
select jt.assert((select count(*) from app_admins where profile_id = jt.pid('clara.putri@example.com')) = 1, 'other admin untouched');

-- The profile row: every personal field cleared, constraints still pass.
select jt.assert((select name from alumni_profiles where id = (select v from t_ids where k = 'ahmad_id')) = 'Deleted user', 'name replaced');
select jt.assert((select email from alumni_profiles where id = (select v from t_ids where k = 'ahmad_id')) = 'deleted-' || (select v from t_ids where k = 'ahmad_id')::text || '@deleted.invalid', 'unique placeholder email');
select jt.assert((select nim from alumni_profiles where id = (select v from t_ids where k = 'ahmad_id')) is null, 'nim cleared');
select jt.assert((select count(*) from alumni_profiles where id = (select v from t_ids where k = 'ahmad_id') and city is null and current_employer is null and "current_role" is null and industry is null and company is null and user_id is null and policy_version is null and policy_accepted_at is null) = 1, 'every optional personal field cleared');
select jt.assert((select faculty || '|' || major || '|' || graduation_year::text from alumni_profiles where id = (select v from t_ids where k = 'ahmad_id')) = '-|-|0', 'required fields hold placeholders');
select jt.assert((select verification_status from alumni_profiles where id = (select v from t_ids where k = 'ahmad_id')) = 'unverified', 'cannot be verified');
select jt.assert((select deleted_at from alumni_profiles where id = (select v from t_ids where k = 'ahmad_id')) > now() - interval '1 minute', 'deleted_at set');
-- A second deletion works too: unique emails and nullable nim do not collide.
set role anon;
select account_delete(jt.pid('bagas.prasetyo@example.com'));
reset role;
select jt.assert((select count(distinct email) from alumni_profiles where deleted_at is not null) = 2, 'two deleted profiles, two unique placeholder emails');
select jt.assert((select count(*) from alumni_profiles where nim is null) = 2, 'two profiles with a null nim');

-- Hidden from every screen: select policy and the email lookup used to verify.
set role anon;
select jt.assert((select count(*) from alumni_profiles where id = (select v from t_ids where k = 'ahmad_id')) = 0, 'deleted profile is invisible to the app');
select jt.assert((select count(*) from alumni_profiles where email = 'ahmad.ramadhan@example.com') = 0, 'the old email finds nothing: cannot verify again');
select jt.assert((select count(*) from alumni_profiles where name = 'Deleted user') = 0, 'not in any list');
-- A deleted person cannot act any more.
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'x')$q$, (select v from t_ids where k = 'ahmad_id'), jt.pid('siti.azizah@example.com')), 'not_verified');
select jt.expect_error(format($q$select account_delete(%L)$q$, (select v from t_ids where k = 'ahmad_id')), 'not_found');
reset role;

-- The dashboard can restore someone from the Ikafe list.
update alumni_profiles set deleted_at = null, name = 'Ahmad Fauzan Ramadhan', email = 'ahmad.ramadhan@example.com', nim = '99999', faculty = 'FEB', major = 'Manajemen', graduation_year = 2023, verification_status = 'verified'
  where id = (select v from t_ids where k = 'ahmad_id');
set role anon;
select jt.assert((select count(*) from alumni_profiles where email = 'ahmad.ramadhan@example.com') = 1, 'restored person is visible and can verify again');
reset role;

rollback;
\o
\echo account deletion checks passed
