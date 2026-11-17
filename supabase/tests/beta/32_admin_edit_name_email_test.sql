-- Admin changes a member's name and email: validation, duplicate email, own
-- email refused, sign in link cleared on a real email change, Riwayat detail.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set verification_status = 'verified', user_id = null, suspended_at = null
  where email in ('ahmad.ramadhan@example.com', 'clara.putri@example.com', 'dewi.sari@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'dewi', jt.pid('dewi.sari@example.com');
delete from app_admins;
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

insert into t_ids select 'uclara', gen_random_uuid();
insert into t_ids select 'udewi', gen_random_uuid();
insert into t_ids select 'uahmad', gen_random_uuid();
insert into auth.users (id, email) select v, case k when 'uclara' then 'clara.putri@example.com' when 'udewi' then 'dewi.sari@example.com' else 'ahmad.ramadhan@example.com' end from t_ids where k like 'u%';
update alumni_profiles set user_id = (select v from t_ids where k = 'uclara') where id = (select v from t_ids where k = 'clara');
update alumni_profiles set user_id = (select v from t_ids where k = 'udewi') where id = (select v from t_ids where k = 'dewi');
update alumni_profiles set user_id = (select v from t_ids where k = 'uahmad') where id = (select v from t_ids where k = 'ahmad');
update app_settings set value = 'on' where key = 'require_login';

-- a plain member cannot
select set_config('test.uid', (select v::text from t_ids where k = 'uahmad'), false);
set role anon;
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"name":"X Y"}')$q$, (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'dewi')), 'not_admin');
reset role;

select set_config('test.uid', (select v::text from t_ids where k = 'uclara'), false);
set role anon;
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"name":"A"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'invalid_input');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"email":"bukan-email"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'invalid_input');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"email":"ahmad.ramadhan@example.com"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'email_taken');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"email":"clara.baru@example.com"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'clara')), 'cannot_change_own_email');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"email":null}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'invalid_input');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"name":"Dewi\nBaru"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'invalid_input');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"email":"DEWI.X@EXAMPLE.COM","nim":"1"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'protected_field');
reset role;
insert into app_admins (profile_id) select v from t_ids where k = 'dewi';
set role anon;
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"email":"dewi.admin.baru@example.com"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'cannot_change_admin_email');
reset role;
delete from app_admins where profile_id = (select v from t_ids where k = 'dewi');
set role anon;
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"nim":"1"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi')), 'protected_field');
-- name only: the sign in link stays
select admin_update_profile((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi'), '{"name":"  Dewi Sari Baru "}');
reset role;
select jt.assert((select name = 'Dewi Sari Baru' and user_id is not null from alumni_profiles where id = (select v from t_ids where k = 'dewi')), 'name changed, sign in link kept');
-- own name is fine
set role anon;
select admin_update_profile((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'clara'), '{"name":"Clara Putri Baru"}');
-- email change (mixed case is saved lower)
select admin_update_profile((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'dewi'), '{"email":"Dewi.Baru@Example.com"}');
reset role;
select jt.assert((select email = 'dewi.baru@example.com' and user_id is null from alumni_profiles where id = (select v from t_ids where k = 'dewi')), 'email changed lower case, sign in link cleared');
select jt.assert(not login_email_known('dewi.sari@example.com'), 'old email gets no code');
select jt.assert(login_email_known('dewi.baru@example.com'), 'new email gets a code');
select jt.assert((select count(*) from admin_actions where action = 'edit_profile'
                    and detail like '%email: dewi.sari@example.com -> dewi.baru@example.com%') = 1, 'email change traceable in Riwayat');
select jt.assert((select count(*) from admin_actions where action = 'edit_profile'
                    and detail like '%nama: % -> Dewi Sari Baru%') = 1, 'name change traceable in Riwayat');

rollback;
\o
\echo admin edit name and email checks passed
