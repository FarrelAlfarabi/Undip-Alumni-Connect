-- Riwayat search: admin only, search text is literal, filters by kind,
-- admin and time, and the limit is capped.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'dewi', jt.pid('dewi.sari@example.com');
insert into t_ids select 'bagas', jt.pid('bagas.prasetyo@example.com');
update alumni_profiles set verification_status = 'verified', user_id = null, suspended_at = null
  where id in (select v from t_ids);
delete from app_admins;
delete from admin_actions;
insert into app_admins (profile_id) values ((select v from t_ids where k = 'clara')), ((select v from t_ids where k = 'bagas'));
insert into admin_actions (admin_id, action, target_type, target_id, detail, created_at) values
  ((select v from t_ids where k = 'clara'), 'member_remove', 'profile', 'x', 'Akun palsu 100%', now()),
  ((select v from t_ids where k = 'clara'), 'admin_add', 'profile', 'y', 'Dewi', now() - interval '10 days'),
  ((select v from t_ids where k = 'bagas'), 'business_approve', 'business', 'z', null, now());

set role anon;
select jt.assert(not has_function_privilege('public', 'admin_actions_search(uuid, text, text, uuid, timestamptz, integer)', 'execute'), 'public cannot search');
select jt.expect_error(format($q$select * from admin_actions_search(%L)$q$, (select v from t_ids where k = 'dewi')), 'not_admin');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'))) = 3, 'all rows');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), 'PALSU')) = 1, 'search by detail, any case');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), '100%')) = 1, 'percent is literal');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), '%')) = 1, 'lone wildcard matches only a real percent');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), null, 'admin_')) = 1, 'kind filter');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), null, '_')) = 0, 'prefix underscore is literal');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), null, null, (select v from t_ids where k = 'bagas'))) = 1, 'admin filter');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), null, null, null, now() - interval '1 day')) = 2, 'time filter');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), null, null, null, null, 1)) = 1, 'limit');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), null, null, null, null, 0)) = 1, 'zero limit gives one row');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), '\')) = 0, 'backslash is literal');
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), 'Clara')) = 2, 'search by admin name');
reset role;

-- With require_login on, an admin id that is not the signed-in person is refused.
insert into t_ids select 'uclara', gen_random_uuid();
insert into auth.users (id, email) values ((select v from t_ids where k = 'uclara'), 'clara.putri@example.com');
update app_settings set value = 'on' where key = 'require_login';
set role anon;
select jt.expect_error(format($q$select * from admin_actions_search(%L)$q$, (select v from t_ids where k = 'clara')), 'not_admin');
reset role;

-- Limit cap (last: adds many rows).
reset role;
select set_config('test.uid', '', false);
update app_settings set value = 'off' where key = 'require_login';
insert into admin_actions (admin_id, action, target_type, target_id)
  select (select v from t_ids where k = 'clara'), 'home_order', 'home', g::text from generate_series(1, 520) g;
set role anon;
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), null, null, null, null, 9999)) = 500, 'limit capped at 500');
reset role;
rollback;
\o
\echo admin log search checks passed
