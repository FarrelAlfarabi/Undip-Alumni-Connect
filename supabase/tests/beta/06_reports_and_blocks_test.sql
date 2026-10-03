-- Stage 6D: reporting, hiding and blocking. All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com', 'clara.putri@example.com');
update alumni_profiles set verification_status = 'unverified' where email = 'rizky.yusuf@example.com';

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

-- Fixtures (dashboard): admin = clara. ahmad owns a job and an approved business
-- with a product. siti is a normal user.
insert into app_admins (profile_id, note) values (jt.pid('clara.putri@example.com'), 'test');
with x as (insert into job_posts (posted_by, title, company, description)
  values (jt.pid('ahmad.ramadhan@example.com'), 'Staff Keuangan', 'PT Maju', 'desc') returning id)
insert into t_ids select 'job', id from x;
with x as (insert into businesses (owner_id, name, description, category, social_link, requested_band, approved_band, status)
  values (jt.pid('ahmad.ramadhan@example.com'), 'Kopi Ahmad', 'Kopi', 'Food & Drink', 'https://instagram.com/kopi_ahmad', 'micro', 'micro', 'approved') returning id)
insert into t_ids select 'biz', id from x;
with x as (insert into marketplace_listings (seller_id, business_id, title, description, price_idr, category, city, image_url, contact_info, status, approved_at)
  values (jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'biz'), 'Kopi Arabika', 'enak', 1000, 'Food & Drink', 'Semarang', 'https://x.example/a.png', 'wa', 'approved', now()) returning id)
insert into t_ids select 'prod', id from x;
with x as (insert into contact_requests (requester_id, target_id, message) values (jt.pid('bagas.prasetyo@example.com'), jt.pid('siti.azizah@example.com'), 'Halo spam') returning id)
insert into t_ids select 'req', id from x;

set role anon;

-- No direct table access.
select jt.expect_error($q$select * from content_reports$q$, 'permission denied');
select jt.expect_error($q$select * from user_blocks$q$, 'permission denied');
select jt.expect_error(format($q$insert into user_blocks values (%L, %L)$q$, jt.pid('siti.azizah@example.com'), jt.pid('ahmad.ramadhan@example.com')), 'permission denied');
select jt.expect_error($q$update content_reports set status = 'dismissed'$q$, 'permission denied');

-- Report rules.
select jt.expect_error(format($q$select content_report_create(%L, 'job', %L, 'spam_or_scam', null)$q$, jt.pid('rizky.yusuf@example.com'), (select v from t_ids where k = 'job')), 'not_verified');
select jt.expect_error(format($q$select content_report_create(%L, 'job', %L, 'spam_or_scam', null)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'job')), 'cannot_report_own');
select jt.expect_error(format($q$select content_report_create(%L, 'business', %L, 'spam_or_scam', null)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'biz')), 'cannot_report_own');
select jt.expect_error(format($q$select content_report_create(%L, 'product', %L, 'spam_or_scam', null)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'prod')), 'cannot_report_own');
select jt.expect_error(format($q$select content_report_create(%L, 'profile', %L, 'other', null)$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('ahmad.ramadhan@example.com')), 'cannot_report_own');
select jt.expect_error(format($q$select content_report_create(%L, 'job', gen_random_uuid(), 'other', null)$q$, jt.pid('siti.azizah@example.com')), 'target_not_found');
select jt.expect_error(format($q$select content_report_create(%L, 'job', %L, 'bad_reason', null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'job')), 'invalid_reason');
select jt.expect_error(format($q$select content_report_create(%L, 'weird', %L, 'other', null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'job')), 'invalid_type');
select jt.expect_error(format($q$select content_report_create(%L, 'job', %L, 'other', %L)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'job'), repeat('x', 301)), 'note_too_long');
-- A received contact request: only the receiver may report it.
select jt.expect_error(format($q$select content_report_create(%L, 'contact_request', %L, 'spam_or_scam', null)$q$, jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'req')), 'cannot_report_own');
select jt.expect_error(format($q$select content_report_create(%L, 'contact_request', %L, 'spam_or_scam', null)$q$, jt.pid('bagas.prasetyo@example.com'), (select v from t_ids where k = 'req')), 'cannot_report_own');
select content_report_create(jt.pid('siti.azizah@example.com'), 'contact_request', (select v from t_ids where k = 'req'), 'spam_or_scam', 'pesan aneh');

-- Valid reports; one open report per target.
select content_report_create(jt.pid('siti.azizah@example.com'), 'job', (select v from t_ids where k = 'job'), 'spam_or_scam', 'lowongan palsu');
select content_report_create(jt.pid('bagas.prasetyo@example.com'), 'job', (select v from t_ids where k = 'job'), 'wrong_info', null);
select jt.expect_error(format($q$select content_report_create(%L, 'job', %L, 'other', null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'job')), 'already_reported');
select content_report_create(jt.pid('siti.azizah@example.com'), 'business', (select v from t_ids where k = 'biz'), 'fake_or_impersonation', null);
select content_report_create(jt.pid('siti.azizah@example.com'), 'profile', jt.pid('ahmad.ramadhan@example.com'), 'inappropriate', null);
-- A marketplace report (the old flow, direct insert allowed by its policy).
insert into marketplace_reports (listing_id, reporter, reason) values ((select v from t_ids where k = 'prod'), jt.pid('siti.azizah@example.com'), 'prohibited');
-- ... which cannot be pre-dismissed by the reporter.
select jt.expect_error(format($q$insert into marketplace_reports (listing_id, reporter, reason, status) values (%L, %L, 'spam', 'dismissed')$q$, (select v from t_ids where k = 'prod'), jt.pid('bagas.prasetyo@example.com')), 'row-level security');

-- Admin rules.
select jt.expect_error(format($q$select * from admin_reports_list(%L, 'open')$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
select jt.expect_error(format($q$select admin_reports_decide(%L, 'job', %L, 'dismiss', null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'job')), 'not_admin');

-- The admin list shows counts and reasons, marketplace reports included.
select jt.assert((select report_count from admin_reports_list(jt.pid('clara.putri@example.com'), 'open') where target_type = 'job') = 2, 'job has 2 open reports');
select jt.assert((select reasons from admin_reports_list(jt.pid('clara.putri@example.com'), 'open') where target_type = 'job') @> array['spam_or_scam', 'wrong_info'], 'reasons listed');
select jt.assert((select title from admin_reports_list(jt.pid('clara.putri@example.com'), 'open') where target_type = 'job') = 'Staff Keuangan (PT Maju)', 'preview of the target');
select jt.assert((select report_count from admin_reports_list(jt.pid('clara.putri@example.com'), 'open') where target_type = 'product') = 1, 'marketplace report appears in the same list');
select jt.assert((select reasons from admin_reports_list(jt.pid('clara.putri@example.com'), 'open') where target_type = 'product') = array['inappropriate'], 'marketplace reason mapped');
select jt.assert((select count(*) from admin_reports_list(jt.pid('clara.putri@example.com'), 'open')) = 5, 'five targets with open reports');

-- Hide a job: gone from the public list. Restore: back.
select jt.assert((select count(*) from job_posts where id = (select v from t_ids where k = 'job')) = 1, 'job visible before');
select jt.expect_error(format($q$select admin_reports_decide(%L, 'job', %L, 'hide', ' ')$q$, jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'job')), 'reason_required');
select jt.expect_error(format($q$select admin_reports_decide(%L, 'profile', %L, 'hide', 'x')$q$, jt.pid('clara.putri@example.com'), jt.pid('ahmad.ramadhan@example.com')), 'invalid_action');
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'job', (select v from t_ids where k = 'job'), 'hide', 'Lowongan palsu');
select jt.assert((select count(*) from job_posts where id = (select v from t_ids where k = 'job')) = 0, 'hidden job is gone from the job list');
select jt.assert((select count(*) from admin_reports_list(jt.pid('clara.putri@example.com'), 'open') where target_type = 'job') = 0, 'its reports are closed (actioned)');
select jt.assert((select count(*) from admin_reports_list(jt.pid('clara.putri@example.com'), 'hidden') where target_type = 'job' and hidden_reason = 'Lowongan palsu') = 1, 'hidden list shows it with the reason');
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'job', (select v from t_ids where k = 'job'), 'restore', null);
select jt.assert((select count(*) from job_posts where id = (select v from t_ids where k = 'job')) = 1, 'restored job is visible again');
-- After the reports were actioned, the same person may report again.
select content_report_create(jt.pid('siti.azizah@example.com'), 'job', (select v from t_ids where k = 'job'), 'other', null);

-- Hide a business: it leaves the directory and ALL its products disappear.
select jt.assert((select count(*) from business_directory(jt.pid('siti.azizah@example.com')) where id = (select v from t_ids where k = 'biz')) = 1, 'business in the directory');
select jt.assert((select count(*) from marketplace_listings where id = (select v from t_ids where k = 'prod')) = 1, 'product visible');
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'business', (select v from t_ids where k = 'biz'), 'hide', 'Penipuan');
select jt.assert((select count(*) from business_directory(jt.pid('siti.azizah@example.com')) where id = (select v from t_ids where k = 'biz')) = 0, 'hidden business leaves the directory');
select jt.assert((select count(*) from marketplace_listings where id = (select v from t_ids where k = 'prod')) = 0, 'hiding a business hides its products');
-- The owner still sees them, marked hidden.
select jt.assert((select hidden_reason from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'biz')) = 'Penipuan', 'owner sees the business with the hidden reason');
select jt.assert((select count(*) from marketplace_my_listings(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'prod')) = 1, 'owner still sees the product');
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'business', (select v from t_ids where k = 'biz'), 'restore', null);
select jt.assert((select count(*) from marketplace_listings where id = (select v from t_ids where k = 'prod')) = 1, 'restored: product visible again');

-- Hide a single product.
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'product', (select v from t_ids where k = 'prod'), 'hide', 'Foto curian');
select jt.assert((select count(*) from marketplace_listings where id = (select v from t_ids where k = 'prod')) = 0, 'hidden product is gone');
select jt.assert((select count(*) from admin_reports_list(jt.pid('clara.putri@example.com'), 'open') where target_type = 'product') = 0, 'product reports closed (marketplace report too)');
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'product', (select v from t_ids where k = 'prod'), 'restore', null);

-- Dismiss and mark actioned.
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'profile', jt.pid('ahmad.ramadhan@example.com'), 'dismiss', null);
select admin_reports_decide(jt.pid('clara.putri@example.com'), 'contact_request', (select v from t_ids where k = 'req'), 'mark_actioned', null);
select jt.assert((select count(*) from admin_reports_list(jt.pid('clara.putri@example.com'), 'open') where target_type in ('profile', 'contact_request')) = 0, 'dismissed and actioned reports leave the open list');
reset role;
select jt.assert((select status from content_reports where target_type = 'profile') = 'dismissed', 'status dismissed');
select jt.assert((select status from content_reports where target_type = 'contact_request') = 'actioned', 'status actioned');
select jt.assert((select reviewed_by from content_reports where target_type = 'profile') = jt.pid('clara.putri@example.com'), 'reviewer recorded');

-- Direct insert path: no privileges, and if a grant and policy were added by
-- mistake the trigger still enforces the rules.
grant insert on content_reports to anon;
create policy tmp_open on content_reports for insert to anon with check (true);
set role anon;
select jt.expect_error(format($q$insert into content_reports (reporter_id, target_type, target_id, reason) values (%L, 'job', %L, 'other')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'job')), 'cannot_report_own');
select jt.expect_error(format($q$insert into content_reports (reporter_id, target_type, target_id, reason) values (%L, 'job', %L, 'other')$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'job')), 'already_reported');
select jt.expect_error(format($q$insert into content_reports (reporter_id, target_type, target_id, reason, status) values (%L, 'job', %L, 'other', 'dismissed')$q$, jt.pid('bagas.prasetyo@example.com'), (select v from t_ids where k = 'job')), 'locked_column');
reset role;
drop policy tmp_open on content_reports;

-- ---------------------------------------------------------------- blocks ---
set role anon;
select jt.expect_error(format($q$select user_block(%L, %L)$q$, jt.pid('siti.azizah@example.com'), jt.pid('siti.azizah@example.com')), 'cannot_block_self');
select jt.expect_error(format($q$select user_block(%L, %L)$q$, jt.pid('rizky.yusuf@example.com'), jt.pid('siti.azizah@example.com')), 'not_verified');
select jt.expect_error(format($q$select user_block(%L, gen_random_uuid())$q$, jt.pid('siti.azizah@example.com')), 'not_found');

-- bagas has an open request to siti (req). siti blocks bagas: request closed.
select user_block(jt.pid('siti.azizah@example.com'), jt.pid('bagas.prasetyo@example.com'));
select user_block(jt.pid('siti.azizah@example.com'), jt.pid('bagas.prasetyo@example.com'));
select jt.assert((select count(*) from user_blocks_list(jt.pid('siti.azizah@example.com'))) = 1, 'one block (twice is the same)');
select jt.assert((select name from user_blocks_list(jt.pid('siti.azizah@example.com')) limit 1) = (select name from alumni_profiles where email = 'bagas.prasetyo@example.com'), 'list shows the name');
select jt.assert((select count(*) from user_blocks_list(jt.pid('bagas.prasetyo@example.com'))) = 0, 'the blocked person has no list entry and is not told');
select jt.assert((select status from contact_requests_incoming(jt.pid('siti.azizah@example.com')) where id = (select v from t_ids where k = 'req')) = 'rejected', 'open request between the two is closed');
select jt.assert((select contact_requests_pending_count(jt.pid('siti.azizah@example.com'))) = 0, 'no waiting requests');

-- The blocked person cannot send a request to the blocker.
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'tolong')$q$, jt.pid('bagas.prasetyo@example.com'), jt.pid('siti.azizah@example.com')), 'blocked');
-- Others can.
select contact_request_send(jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com'), 'hai');
-- Blocks both directions close open requests: ahmad -> siti is open, siti blocks ahmad.
select user_block(jt.pid('siti.azizah@example.com'), jt.pid('ahmad.ramadhan@example.com'));
select jt.assert((select contact_requests_pending_count(jt.pid('siti.azizah@example.com'))) = 0, 'request from the newly blocked person is closed');

-- business_directory leaves out the blocked person's business for the blocker only.
select jt.assert((select count(*) from business_directory(jt.pid('siti.azizah@example.com')) where id = (select v from t_ids where k = 'biz')) = 0, 'blocker does not see the blocked owner business');
select jt.assert((select count(*) from business_directory(jt.pid('clara.putri@example.com')) where id = (select v from t_ids where k = 'biz')) = 1, 'others still see it');

-- Unblock restores.
select user_unblock(jt.pid('siti.azizah@example.com'), jt.pid('ahmad.ramadhan@example.com'));
select jt.assert((select count(*) from business_directory(jt.pid('siti.azizah@example.com')) where id = (select v from t_ids where k = 'biz')) = 1, 'unblocked: visible again');
select jt.assert((select count(*) from user_blocks_list(jt.pid('siti.azizah@example.com'))) = 1, 'one block left');
reset role;

rollback;
\o
\echo reports and blocks checks passed
