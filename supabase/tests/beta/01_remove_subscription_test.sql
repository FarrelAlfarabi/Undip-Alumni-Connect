-- Stage 3: no subscription. Verified alumni post jobs for free. Marketplace
-- posting stays closed until the business directory opens it (Stage 6).
\set ON_ERROR_STOP on
\o /dev/null
begin;

-- Fixtures (postgres role): ahmad free, siti subscribed, rizky unverified.
update alumni_profiles set subscription_status = 'free', verification_status = 'verified' where email = 'ahmad.ramadhan@example.com';
update alumni_profiles set subscription_status = 'subscribed', verification_status = 'verified' where email = 'siti.azizah@example.com';
update alumni_profiles set verification_status = 'unverified' where email = 'rizky.yusuf@example.com';

set role anon;

-- A FREE verified alumnus can post a job. No limit.
insert into job_posts (posted_by, title, company, description) values (jt.pid('ahmad.ramadhan@example.com'), 'free job 1', 'c', 'd');
insert into job_posts (posted_by, title, company, description) values (jt.pid('ahmad.ramadhan@example.com'), 'free job 2', 'c', 'd');
insert into job_posts (posted_by, title, company, description) values (jt.pid('ahmad.ramadhan@example.com'), 'free job 3', 'c', 'd');
select jt.assert(jt.count_of($q$select 1 from job_posts where title like 'free job %'$q$) = 3, 'three free jobs are visible');

-- Still refused: no poster, unknown poster, unverified poster.
select jt.expect_error($q$insert into job_posts (posted_by, title, company, description) values (null, 't', 'c', 'd')$q$, 'verified_poster_required');
select jt.expect_error($q$insert into job_posts (posted_by, title, company, description) values (gen_random_uuid(), 't', 'c', 'd')$q$, 'verified_poster_required');
select jt.expect_error(format($q$insert into job_posts (posted_by, title, company, description) values (%L, 't', 'c', 'd')$q$, jt.pid('rizky.yusuf@example.com')), 'verified_poster_required');

-- The subscription machinery is switched off for the app.
select jt.expect_error(format($q$select demo_subscribe(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'permission denied');
select jt.expect_error($q$select * from billing_settings$q$, 'permission denied');
select jt.expect_error(format($q$update alumni_profiles set subscription_status = 'subscribed' where id = %L$q$, jt.pid('ahmad.ramadhan@example.com')), 'subscription_status can only be changed');
-- Fields the app still edits keep working.
update alumni_profiles set industry = 'Technology' where id = jt.pid('ahmad.ramadhan@example.com');

-- Marketplace posting is closed, even for a subscribed seller.
select jt.expect_error(format($q$select marketplace_create_listing(%L, 'Title ok', 'desc', 1000, 'Other', 'Semarang', 'https://x.example/a.png', null, 'wa')$q$, jt.pid('siti.azizah@example.com')), 'posting_closed');
-- Existing listings stay visible; edit and delete paths are untouched.
select jt.assert(jt.count_of($q$select 1 from marketplace_listings$q$) > 0, 'approved seeded listings are still visible');

reset role;

-- Dashboard / owner is exempt, and all subscription data is kept.
insert into job_posts (posted_by, title, company, description) values (null, 'owner insert', 'c', 'd');
select jt.assert((select demo_subscriptions from billing_settings) = false, 'demo_subscriptions is off');
select jt.assert((select count(*) from alumni_profiles where subscription_status = 'subscribed') >= 1, 'subscription_status data kept');
select jt.assert(to_regclass('public.billing_settings') is not null, 'billing_settings kept');

rollback;
\o
\echo remove-subscription checks passed
