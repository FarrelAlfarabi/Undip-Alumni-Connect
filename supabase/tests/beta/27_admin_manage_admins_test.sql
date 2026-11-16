-- In-app admin management: list, add, remove. Non-admins refused; self, last
-- admin and owner cannot be removed; each change writes a Riwayat row.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set verification_status = 'verified', user_id = null, suspended_at = null
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com',
                  'dewi.sari@example.com', 'bagas.prasetyo@example.com', 'fajar.nugroho@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'dewi', jt.pid('dewi.sari@example.com');
insert into t_ids select 'bagas', jt.pid('bagas.prasetyo@example.com');
insert into t_ids select 'fajar', jt.pid('fajar.nugroho@example.com');
delete from app_admins;
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

-- With the login switch off, the functions refuse outright.
set role anon;
select jt.expect_error(format($q$select * from admin_admins_list(%L)$q$, (select v from t_ids where k = 'clara')), 'login_required');
select jt.expect_error(format($q$select admin_admin_add(%L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'siti')), 'login_required');
select jt.expect_error(format($q$select admin_admin_remove(%L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'siti')), 'login_required');
select jt.assert(not has_function_privilege('public', 'admin_admin_add(uuid, uuid)', 'execute'), 'public cannot add admins');
reset role;

-- Login on. Each person gets an auth user; test.uid says who is signed in.
alter table auth.users add column if not exists email text;
insert into t_ids select 'u' || k, gen_random_uuid() from t_ids;
insert into auth.users (id, email) select u.v, p.email from t_ids u join t_ids k on 'u' || k.k = u.k join alumni_profiles p on p.id = k.v;
update alumni_profiles p set user_id = u.v from t_ids k join t_ids u on u.k = 'u' || k.k where p.id = k.v;
update app_settings set value = 'on' where key = 'require_login';
create or replace function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('test.uid', (select v::text from t_ids where k = 'u' || p), false) $$;

set role anon;
select pg_temp.as_user('siti');
select jt.expect_error(format($q$select * from admin_admins_list(%L)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error(format($q$select admin_admin_add(%L, %L)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'siti')), 'not_admin');
-- siti signed in, claiming to be clara
select jt.expect_error(format($q$select admin_admin_add(%L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'siti')), 'not_admin');
select pg_temp.as_user('clara');
select jt.assert((select count(*) from admin_admins_list((select v from t_ids where k = 'clara'))) = 1, 'one admin listed');
select jt.expect_error(format($q$select admin_admin_remove(%L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'clara')), 'cannot_remove_self');
select admin_admin_add((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi'));
select jt.expect_error(format($q$select admin_admin_add(%L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'already_admin');
select jt.expect_error(format($q$select admin_admin_add(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'clara')), 'not_found');
reset role;
update alumni_profiles set suspended_at = now(), suspended_reason = 't' where id = (select v from t_ids where k = 'fajar');
set role anon;
select jt.expect_error(format($q$select admin_admin_add(%L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'fajar')), 'invalid_state');
select pg_temp.as_user('dewi');
select jt.assert((select count(*) from admin_admins_list((select v from t_ids where k = 'dewi'))) = 2, 'new admin can list');
select pg_temp.as_user('siti');
select jt.expect_error(format($q$select admin_admin_remove(%L, %L)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'dewi')), 'not_admin');
select pg_temp.as_user('clara');
select jt.expect_error(format($q$select admin_admin_remove(%L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'siti')), 'not_found');
reset role;
update app_admins set is_owner = true where profile_id = (select v from t_ids where k = 'clara');
set role anon;
select pg_temp.as_user('dewi');
select jt.expect_error(format($q$select admin_admin_remove(%L, %L)$q$, (select v from t_ids where k = 'dewi'), (select v from t_ids where k = 'clara')), 'owner_protected');
select pg_temp.as_user('clara');
select admin_admin_remove((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi'));
select jt.assert(not is_app_admin((select v from t_ids where k = 'dewi')), 'removed admin is no longer admin');
select pg_temp.as_user('dewi');
select jt.expect_error(format($q$select * from admin_admins_list(%L)$q$, (select v from t_ids where k = 'dewi')), 'not_admin');
reset role;
select jt.assert((select count(*) from admin_actions where action in ('admin_add', 'admin_remove')) = 2, 'add and remove are logged');
select jt.assert(not has_table_privilege('anon', 'app_admins', 'select'), 'anon still cannot read app_admins');

rollback;
\o
\echo admin management checks passed
