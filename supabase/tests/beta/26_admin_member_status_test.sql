-- Admin member list: status columns, suspend / unsuspend, NIM and jurusan fix.
-- Non-admins are refused; admins and yourself cannot be suspended; every
-- change writes a Riwayat row.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set verification_status = 'verified', user_id = null, suspended_at = null
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com',
                  'dewi.sari@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'dewi', jt.pid('dewi.sari@example.com');
delete from app_admins;
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'dewi'), 'test');
update alumni_profiles set nim = 'NIMLAMA001' where id = (select v from t_ids where k = 'ahmad');
update alumni_profiles set nim = 'NIMSITI0001' where id = (select v from t_ids where k = 'siti');

set role anon;
-- search returns status columns and lists suspended members
select jt.expect_error(format($q$select * from admin_members_list(%L)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.assert((select is_admin from admin_members_list((select v from t_ids where k = 'clara'))
                   where id = (select v from t_ids where k = 'dewi')), 'admin flag shown');
select jt.assert((select not is_admin and suspended_at is null from admin_members_list((select v from t_ids where k = 'clara'))
                   where id = (select v from t_ids where k = 'ahmad')), 'member not admin, not suspended');

-- suspend
select jt.assert(not has_function_privilege('public', 'admin_member_set_suspended(uuid, uuid, boolean, text)', 'execute'), 'public cannot suspend');
select jt.expect_error(format($q$select admin_member_set_suspended(%L, %L, true, 'spam')$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.expect_error(format($q$select admin_member_set_suspended(%L, %L, true, '  ')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'reason_required');
select jt.expect_error(format($q$select admin_member_set_suspended(%L, %L, true, 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'clara')), 'invalid_state');
select jt.expect_error(format($q$select admin_member_set_suspended(%L, %L, true, 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'invalid_state');
select jt.expect_error(format($q$select admin_member_set_suspended(%L, gen_random_uuid(), true, 'x')$q$, (select v from t_ids where k = 'clara')), 'not_found');
select jt.expect_error(format($q$select admin_member_set_suspended(%L, %L, false)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'invalid_state');
select admin_member_set_suspended((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), true, 'Akun palsu');
select jt.assert((select suspended_at is not null and suspended_reason = 'Akun palsu' from admin_members_list((select v from t_ids where k = 'clara'))
                   where id = (select v from t_ids where k = 'ahmad')), 'suspended member still listed for admins');
select jt.expect_error(format($q$select admin_member_set_suspended(%L, %L, true, 'lagi')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'invalid_state');
select admin_member_set_suspended((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), false);
reset role;
select jt.assert((select suspended_at is null and suspended_reason is null from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'unsuspended');
select jt.assert((select count(*) from admin_actions where action in ('member_suspend', 'member_unsuspend')
                    and target_id = (select v from t_ids where k = 'ahmad')::text) = 2, 'suspend and unsuspend logged');

-- NIM and jurusan
set role anon;
select jt.expect_error(format($q$select * from admin_member_identity(%L, %L)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.assert((select nim from admin_member_identity((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'))) = 'NIMLAMA001', 'admin reads NIM for the fix form');
select jt.expect_error(format($q$select * from admin_member_identity(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'clara')), 'not_found');
select jt.expect_error(format($q$select admin_member_set_identity(%L, %L, '21010118120001', 'Akuntansi')$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.expect_error(format($q$select admin_member_set_identity(%L, %L, '12', 'Akuntansi')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'invalid_input');
select jt.expect_error(format($q$select admin_member_set_identity(%L, %L, '21010118120001', ' ')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'invalid_input');
select jt.expect_error(format($q$select admin_member_set_identity(%L, %L, 'NIM 123;--', 'Akuntansi')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'invalid_input');
select jt.expect_error(format($q$select admin_member_set_identity(%L, %L, %L, 'Akuntansi')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), repeat('1', 31)), 'invalid_input');
select jt.expect_error(format($q$select admin_member_set_identity(%L, %L, '2101011812', %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), repeat('a', 81)), 'invalid_input');
select jt.expect_error(format($q$select admin_member_set_identity(%L, %L, 'nimsiti0001', 'Akuntansi')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'nim_taken');
select admin_member_set_identity((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), ' 21010118120001 ', 'Akuntansi');
reset role;
select jt.assert((select nim = '21010118120001' and major = 'Akuntansi' from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'NIM and jurusan fixed');
select jt.assert((select detail from admin_actions where action = 'member_fix_identity' order by created_at desc limit 1) !~ '2101', 'log has field names, not the NIM');
select jt.assert(not has_column_privilege('anon', 'public.alumni_profiles', 'nim', 'select'), 'NIM still hidden from the app');

-- Older builds: admin_members_search still works. Deleted members are not listed.
set role anon;
select jt.assert((select count(*) from admin_members_search((select v from t_ids where k = 'clara'), 'ahmad')) = 1, 'old search still works');
select jt.assert((select count(*) from admin_members_list((select v from t_ids where k = 'clara'), '%')) = 0, 'LIKE wildcards are literal');
reset role;
update alumni_profiles set deleted_at = now() where id = (select v from t_ids where k = 'siti');
set role anon;
select jt.assert((select count(*) from admin_members_list((select v from t_ids where k = 'clara')) where id = (select v from t_ids where k = 'siti')) = 0, 'deleted member not listed');
reset role;

-- With require_login on, an admin id that is not the signed-in person is refused.
insert into t_ids select 'uclara', gen_random_uuid();
insert into auth.users (id, email) values ((select v from t_ids where k = 'uclara'), 'clara.putri@example.com');
update app_settings set value = 'on' where key = 'require_login';
set role anon;
select jt.expect_error(format($q$select admin_member_set_suspended(%L, %L, true, 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.expect_error(format($q$select * from admin_member_identity(%L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.expect_error(format($q$select * from admin_members_list(%L)$q$, (select v from t_ids where k = 'clara')), 'not_admin|not_signed_in');
reset role;
-- ... and the real admin, signed in as themself, can act.
update alumni_profiles set user_id = (select v from t_ids where k = 'uclara') where id = (select v from t_ids where k = 'clara');
select set_config('test.uid', (select v from t_ids where k = 'uclara')::text, true);
set role anon;
select jt.assert((select count(*) from admin_members_list((select v from t_ids where k = 'clara'))) > 0, 'signed-in admin lists members');
select admin_member_set_suspended((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), true, 'uji');
select jt.assert((select suspended_at is not null from admin_members_list((select v from t_ids where k = 'clara')) where id = (select v from t_ids where k = 'ahmad')), 'signed-in admin suspended');
-- a signed-in non-admin naming the admin id is refused
reset role;
select set_config('test.uid', gen_random_uuid()::text, true);
set role anon;
select jt.expect_error(format($q$select admin_member_set_suspended(%L, %L, false)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'not_admin');
reset role;

rollback;
\o
\echo admin member status checks passed
