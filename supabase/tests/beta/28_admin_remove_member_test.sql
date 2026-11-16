-- Admin "Hapus anggota": non-admins refused, reason required, self and admins
-- protected, data removed like the member's own delete, Riwayat row written,
-- and the member's own delete still works.
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

set role anon;
select jt.expect_error(format($q$select admin_member_remove(%L, %L, 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'login_required');
select jt.assert(not has_function_privilege('anon', 'account_delete_core(uuid)', 'execute'), 'anon cannot call the delete core');
select jt.assert(not has_function_privilege('authenticated', 'account_delete_core(uuid)', 'execute'), 'signed-in app cannot call the delete core');
reset role;

alter table auth.users add column if not exists email text;
insert into t_ids select 'u' || k, gen_random_uuid() from t_ids;
insert into auth.users (id, email) select u.v, p.email from t_ids u join t_ids k on 'u' || k.k = u.k join alumni_profiles p on p.id = k.v;
update alumni_profiles p set user_id = u.v from t_ids k join t_ids u on u.k = 'u' || k.k where p.id = k.v;
update app_settings set value = 'on' where key = 'require_login';
create or replace function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('test.uid', (select v::text from t_ids where k = 'u' || p), false) $$;
insert into app_admins (profile_id) values ((select v from t_ids where k = 'bagas'));
insert into job_posts (posted_by, title, company, description) values ((select v from t_ids where k = 'ahmad'), 'Lowongan Ahmad', 'c', 'd');

set role anon;
select pg_temp.as_user('siti');
select jt.expect_error(format($q$select admin_member_remove(%L, %L, 'palsu')$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.expect_error(format($q$select admin_member_remove(%L, %L, 'palsu')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.expect_error(format($q$select account_delete(%L)$q$, (select v from t_ids where k = 'ahmad')), 'not_signed_in');
select pg_temp.as_user('clara');
select jt.expect_error(format($q$select admin_member_remove(%L, %L, '  ')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'reason_required');
select jt.expect_error(format($q$select admin_member_remove(%L, %L, 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'clara')), 'cannot_remove_self');
select jt.expect_error(format($q$select admin_member_remove(%L, %L, 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'bagas')), 'target_is_admin');
select jt.expect_error(format($q$select admin_member_remove(%L, gen_random_uuid(), 'x')$q$, (select v from t_ids where k = 'clara')), 'not_found');
select jt.assert((select (admin_member_remove((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), 'Akun palsu') ->> 'deleted')::boolean), 'admin removed the member');
select jt.expect_error(format($q$select admin_member_remove(%L, %L, 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'not_found');
reset role;
select jt.assert((select deleted_at is not null and name = 'Deleted user' and user_id is null
                    from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'profile anonymised');
select jt.assert((select count(*) from businesses where owner_id = (select v from t_ids where k = 'ahmad')) = 0, 'businesses gone');
select jt.assert((select count(*) from marketplace_listings where seller_id = (select v from t_ids where k = 'ahmad')) = 0, 'listings gone');
select jt.assert((select count(*) from job_posts where posted_by = (select v from t_ids where k = 'ahmad')) = 0, 'jobs gone');
select jt.assert((select count(*) from admin_actions where action = 'member_remove'
                    and target_id = (select v from t_ids where k = 'ahmad')::text and detail like '%Akun palsu%') = 1, 'removal logged');

-- the member's own delete still works when signed in as themself
set role anon;
select pg_temp.as_user('siti');
select jt.assert((select (account_delete((select v from t_ids where k = 'siti')) ->> 'deleted')::boolean), 'self delete still works');
reset role;
select jt.assert((select deleted_at is not null from alumni_profiles where id = (select v from t_ids where k = 'siti')), 'self delete anonymised');

rollback;
\o
\echo admin remove member checks passed
