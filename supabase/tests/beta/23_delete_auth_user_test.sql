-- Deleting an account also removes the Supabase Auth user, so the person
-- can no longer sign in and no login record stays behind.
-- Runs in a transaction that is rolled back.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ua', gen_random_uuid();
insert into t_ids select 'us', gen_random_uuid();
insert into auth.users (id, email) values
  ((select v from t_ids where k = 'ua'), 'ahmad.ramadhan@example.com'),
  ((select v from t_ids where k = 'us'), 'siti.azizah@example.com');
update alumni_profiles set user_id = (select v from t_ids where k = 'ua') where email = 'ahmad.ramadhan@example.com';
update alumni_profiles set user_id = (select v from t_ids where k = 'us') where email = 'siti.azizah@example.com';
insert into t_ids select 'ahmad_id', id from alumni_profiles where email = 'ahmad.ramadhan@example.com';

-- Ahmad leaves (login switch is off here, so the id alone is enough).
set role anon;
select account_delete((select v from t_ids where k = 'ahmad_id'));
reset role;

select jt.assert((select count(*) from auth.users where id = (select v from t_ids where k = 'ua')) = 0, 'auth user of the deleted person is gone');
select jt.assert((select count(*) from auth.users where id = (select v from t_ids where k = 'us')) = 1, 'auth user of someone else stays');
select jt.assert((select user_id is null from alumni_profiles where id = (select v from t_ids where k = 'ahmad_id')), 'profile no longer points at an auth user');
select jt.assert((select user_id from alumni_profiles where email = 'siti.azizah@example.com') = (select v from t_ids where k = 'us'), 'other profile still linked');

-- A profile without an auth user (never logged in with a code) deletes fine.
set role anon;
select account_delete(jt.pid('bagas.prasetyo@example.com'));
reset role;
select jt.assert((select deleted_at is not null from alumni_profiles where email like 'deleted-%' limit 1), 'profile without auth user still deletes');

-- The dashboard path: marking a profile deleted by hand removes the auth user too.
update alumni_profiles set deleted_at = now() where email = 'siti.azizah@example.com';
select jt.assert((select count(*) from auth.users where id = (select v from t_ids where k = 'us')) = 0, 'manual deleted_at also removes the auth user');

rollback;
\o
\echo auth user deletion checks passed
