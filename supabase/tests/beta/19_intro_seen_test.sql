-- First-login intro: intro_seen_at starts empty, account_mark_intro_seen()
-- sets it once, account_intro_seen() reads it, and with require_login on only
-- the owner can use either function.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set intro_seen_at = null, verification_status = 'verified', user_id = null
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com');
set role anon;

select jt.assert(not account_intro_seen(jt.pid('ahmad.ramadhan@example.com')), 'starts unseen');
select jt.assert(not account_intro_seen(null), 'null id is unseen');

-- Marking sets it.
select account_mark_intro_seen(jt.pid('ahmad.ramadhan@example.com'));
select jt.assert(account_intro_seen(jt.pid('ahmad.ramadhan@example.com')), 'marked as seen');

-- Marking again keeps the first time.
reset role;
update alumni_profiles set intro_seen_at = '2026-01-01T00:00:00Z' where email = 'ahmad.ramadhan@example.com';
set role anon;
select account_mark_intro_seen(jt.pid('ahmad.ramadhan@example.com'));
reset role;
select jt.assert(
  (select intro_seen_at = '2026-01-01T00:00:00Z' from alumni_profiles where email = 'ahmad.ramadhan@example.com'),
  'second call keeps the first time');

-- Unknown or empty ids change nothing and do not fail.
set role anon;
select account_mark_intro_seen(null);
select account_mark_intro_seen('00000000-0000-0000-0000-000000000000');
reset role;

-- A deleted profile is left alone.
update alumni_profiles set intro_seen_at = null, deleted_at = now() where email = 'siti.azizah@example.com';
set role anon;
select account_mark_intro_seen(jt.pid('siti.azizah@example.com'));
select jt.assert(not account_intro_seen(jt.pid('siti.azizah@example.com')), 'deleted profile stays unseen');
reset role;
update alumni_profiles set deleted_at = null where email = 'siti.azizah@example.com';

-- Not callable through "public": only anon and authenticated may execute.
select jt.assert(not has_function_privilege('public', 'account_mark_intro_seen(uuid)', 'execute'), 'public cannot mark');
select jt.assert(has_function_privilege('anon', 'account_mark_intro_seen(uuid)', 'execute'), 'anon can mark');
select jt.assert(not has_function_privilege('public', 'account_intro_seen(uuid)', 'execute'), 'public cannot read');

-- ---- require_login on: only the owner ------------------------------------
create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ua', gen_random_uuid();
insert into auth.users (id, email) values
  ((select v from t_ids where k = 'ua'), 'ahmad.ramadhan@example.com');
update alumni_profiles set intro_seen_at = null, user_id = null where email = 'ahmad.ramadhan@example.com';
update app_settings set value = 'on' where key = 'require_login';

set role anon;
select jt.expect_error(format($q$select account_mark_intro_seen(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
select jt.expect_error(format($q$select account_intro_seen(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_signed_in');
reset role;

select set_config('test.uid', (select v::text from t_ids where k = 'ua'), true);
set role authenticated;
select claim_alumni_profile();
select account_mark_intro_seen(jt.pid('ahmad.ramadhan@example.com'));
select jt.assert(account_intro_seen(jt.pid('ahmad.ramadhan@example.com')), 'owner marks own');
-- ...but not someone else's.
select jt.expect_error(format($q$select account_mark_intro_seen(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_signed_in');
select jt.expect_error(format($q$select account_intro_seen(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_signed_in');
reset role;

rollback;
\o
\echo intro seen checks passed
