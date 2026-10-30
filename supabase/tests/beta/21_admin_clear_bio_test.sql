-- Admin "Hapus bio": only an admin, only the bio, unknown profile is refused.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set verification_status = 'verified', user_id = null
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');
update alumni_profiles set bio = 'Bio yang dilaporkan' where id = (select v from t_ids where k = 'ahmad');

set role anon;
select jt.assert(not has_function_privilege('public', 'admin_clear_bio(uuid, uuid)', 'execute'), 'public cannot clear a bio');
select jt.expect_error(format($q$select admin_clear_bio(%L, %L)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.assert((select bio from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = 'Bio yang dilaporkan', 'non-admin changed nothing');
select admin_clear_bio((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'));
select jt.assert((select bio is null from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'admin cleared the bio');
select jt.assert((select count(*) from alumni_profiles where id = (select v from t_ids where k = 'ahmad') and deleted_at is null and verification_status = 'verified') = 1, 'account untouched');
select jt.expect_error(format($q$select admin_clear_bio(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'clara')), 'not_found');
reset role;

-- With require_login on, an admin id that is not the signed-in person is refused.
insert into t_ids select 'uclara', gen_random_uuid();
insert into auth.users (id, email) values ((select v from t_ids where k = 'uclara'), 'clara.putri@example.com');
update app_settings set value = 'on' where key = 'require_login';
set role anon;
select jt.expect_error(format($q$select admin_clear_bio(%L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'not_admin');
reset role;

rollback;
\o
\echo admin clear bio checks passed
