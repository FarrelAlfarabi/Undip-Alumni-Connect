-- Real login: dormant while require_login is off, strict when it is on, and
-- the cutover / rollback scripts work. Runs in a transaction that is rolled back.
\set ON_ERROR_STOP on
\o /dev/null
begin;

-- Stand-ins: auth.users gets an email, auth.uid() reads a test setting.
alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set verification_status = 'verified', user_id = null
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com');
update alumni_profiles set verification_status = 'failed', user_id = null
  where email = 'clara.putri@example.com';

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ua', gen_random_uuid();
insert into t_ids select 'us', gen_random_uuid();
insert into t_ids select 'uc', gen_random_uuid();
insert into auth.users (id, email) values
  ((select v from t_ids where k = 'ua'), 'Ahmad.Ramadhan@example.com'),
  ((select v from t_ids where k = 'us'), 'siti.azizah@example.com'),
  ((select v from t_ids where k = 'uc'), 'clara.putri@example.com');
insert into app_admins (profile_id) values (jt.pid('siti.azizah@example.com')) on conflict do nothing;

-- ---- switch OFF: nothing changes ----------------------------------------
select jt.assert((select value from app_settings where key = 'require_login') = 'off', 'default is off');
set role anon;
select jt.assert(not login_required(), 'off');
select business_my(jt.pid('ahmad.ramadhan@example.com'));
select jt.assert(is_app_admin(jt.pid('siti.azizah@example.com')), 'off: admin id alone still works');
select jt.assert(login_email_known('AHMAD.ramadhan@example.com '), 'email known, any case');
select jt.assert(not login_email_known('nobody@example.com'), 'unknown email');
select jt.assert(not login_email_known('clara.putri@example.com'), 'a revoked person gets no code');
reset role;

-- ---- switch ON -----------------------------------------------------------
update app_settings set value = 'on' where key = 'require_login';
set role anon;
select jt.assert(login_required(), 'on');
select jt.expect_error(format($q$select business_my(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
select jt.expect_error(format($q$select notifications_list(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
select jt.expect_error(format($q$select user_blocks_list(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
select jt.assert(not is_app_admin(jt.pid('siti.azizah@example.com')), 'on: spoofed admin id is refused');
select jt.expect_error(format($q$select * from admin_businesses_list(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
select jt.expect_error($q$select claim_alumni_profile()$q$, 'permission denied');
reset role;

-- Signed in as Ahmad's auth user but not linked yet: still not his profile.
select set_config('test.uid', (select v::text from t_ids where k = 'ua'), true);
set role authenticated;
select jt.expect_error(format($q$select business_my(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
-- Claim links by email (any case) and verifies.
select jt.assert((select (claim_alumni_profile()).id) = jt.pid('ahmad.ramadhan@example.com'), 'claim links Ahmad');
select business_my(jt.pid('ahmad.ramadhan@example.com'));
select jt.expect_error(format($q$select business_my(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_signed_in');
select jt.expect_error(format($q$select user_block(%L, %L)$q$, jt.pid('siti.azizah@example.com'), jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
select jt.assert(not is_app_admin(jt.pid('siti.azizah@example.com')), 'Ahmad cannot act as admin Siti');
select jt.assert(not is_app_admin(jt.pid('ahmad.ramadhan@example.com')), 'Ahmad is not an admin');
reset role;

-- Siti signs in: her admin id now works for her only.
select set_config('test.uid', (select v::text from t_ids where k = 'us'), true);
set role authenticated;
select claim_alumni_profile();
select jt.assert(is_app_admin(jt.pid('siti.azizah@example.com')), 'Siti is admin when signed in as Siti');
select * from admin_businesses_list(jt.pid('siti.azizah@example.com'));
reset role;

-- A revoked person can sign in to Auth but stays failed.
select set_config('test.uid', (select v::text from t_ids where k = 'uc'), true);
set role authenticated;
select jt.assert((select (claim_alumni_profile()).verification_status) = 'failed', 'revoked stays failed');
reset role;
select set_config('test.uid', '', true);

-- ---- cutover and its rollback --------------------------------------------
update app_settings set value = 'off' where key = 'require_login';
\o
\i supabase/cutover_real_login.sql
\o /dev/null
select jt.assert((select value from app_settings where key = 'require_login') = 'on', 'cutover turns it on');
select jt.assert(not exists (select 1 from pg_policies where policyname in
  ('alumni_profiles_update_anon','job_posts_insert_anon','conversations_select_anon',
   'conversations_insert_anon','messages_select_anon','messages_insert_anon')), 'anon write policies gone');
set role anon;
select jt.expect_error($q$select * from verify_alumni_email('ahmad.ramadhan@example.com')$q$, 'permission denied');
reset role;
\o
\i supabase/rollback_cutover_real_login.sql
\i supabase/rollback_cutover_real_login.sql
\o /dev/null
select jt.assert((select value from app_settings where key = 'require_login') = 'off', 'cutover rollback');
select jt.assert((select count(*) from pg_policies where policyname = 'alumni_profiles_update_anon') = 1, 'policy back, once');
set role anon;
select * from verify_alumni_email('ahmad.ramadhan@example.com');
reset role;

rollback;
\o
\echo 15_real_login_test: ok
