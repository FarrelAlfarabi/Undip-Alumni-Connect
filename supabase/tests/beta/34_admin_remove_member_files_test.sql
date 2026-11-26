-- Admin "Hapus anggota" still works when account_files() checks the caller.
-- On the demo database (and wherever the real login patch is applied last)
-- account_files() starts with assert_caller(p_profile), which refused an admin
-- deleting someone else: "not_signed_in" (HTTP 403). The delete core must use
-- an internal file list instead, and clients still cannot read other
-- people's file paths.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

-- the real login patch, applied to account_files the way the demo database has it
create or replace function pg_temp.guard_account_files() returns void language plpgsql as $f$
declare v_def text;
begin
  if pg_get_functiondef('public.account_files(uuid)'::regprocedure) like '%assert_caller(%' then return; end if;
  v_def := replace(pg_get_functiondef('public.account_files(uuid)'::regprocedure),
                   'AS $function$' || chr(10), 'AS $function$' || chr(10) || '  select assert_caller(p_profile);' || chr(10));
  if v_def not like '%select assert_caller(p_profile);%' then raise exception 'patch did not apply'; end if;
  execute v_def;
end $f$;
select pg_temp.guard_account_files();

update alumni_profiles set verification_status = 'verified', user_id = null, suspended_at = null
  where email in ('ahmad.ramadhan@example.com', 'clara.putri@example.com', 'siti.azizah@example.com');
create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
delete from app_admins;
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');
insert into t_ids select 'u' || k, gen_random_uuid() from t_ids;
insert into auth.users (id, email) select u.v, p.email from t_ids u join t_ids k on 'u' || k.k = u.k join alumni_profiles p on p.id = k.v;
update alumni_profiles p set user_id = u.v from t_ids k join t_ids u on u.k = 'u' || k.k where p.id = k.v;
update app_settings set value = 'on' where key = 'require_login';
create or replace function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('test.uid', (select v::text from t_ids where k = 'u' || p), false) $$;

set role anon;
select pg_temp.as_user('clara');
select jt.assert((select (admin_member_remove((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), 'Akun palsu') ->> 'deleted')::boolean),
                 'admin removed a member although account_files checks the caller');
-- someone else's file list stays private
select jt.expect_error(format($q$select * from account_files(%L)$q$, (select v from t_ids where k = 'siti')), 'not_signed_in');
select jt.assert(not has_function_privilege('anon', 'account_files_core(uuid)', 'execute'), 'anon cannot call the file list core');
select jt.assert(not has_function_privilege('authenticated', 'account_files_core(uuid)', 'execute'), 'signed-in app cannot call the file list core');
reset role;
select jt.assert((select deleted_at is not null from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'member removed');

rollback;
\o
\echo admin remove member files checks passed
