-- Riwayat names who the action was done to: removing a member keeps the
-- member's name and email in target_label (the profile is erased), a jurusan
-- fix gets the label from the trigger, and the search returns and matches it.
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
insert into auth.users (id, email) select v, 'clara.putri@example.com' from t_ids where k = 'uclara';
update alumni_profiles set user_id = (select v from t_ids where k = 'uclara') where id = (select v from t_ids where k = 'clara');
update app_settings set value = 'on' where key = 'require_login';

select set_config('test.uid', (select v::text from t_ids where k = 'uclara'), false);
set role anon;
select admin_member_remove((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), 'Akun palsu');
reset role;

select jt.assert((select target_label like 'Ahmad%' and target_label like '%ahmad.ramadhan@example.com%'
                    from admin_actions where action = 'member_remove'
                     and target_id = (select v from t_ids where k = 'ahmad')::text),
                 'removal keeps name and email after the profile is erased');
select jt.assert((select name = 'Deleted user' from alumni_profiles where id = (select v from t_ids where k = 'ahmad')),
                 'profile itself is erased');

-- the trigger fills the label when the writer gives none
insert into admin_actions (admin_id, action, target_type, target_id, detail)
  values ((select v from t_ids where k = 'clara'), 'member_fix_major', 'profile',
          (select v::text from t_ids where k = 'dewi'), 'a -> b');
select jt.assert((select target_label like '%dewi.sari@example.com%'
                    from admin_actions where action = 'member_fix_major'
                     and target_id = (select v::text from t_ids where k = 'dewi')
                   order by created_at desc limit 1), 'trigger fills the label');

-- the search returns the label and matches on it
set role anon;
select jt.assert((select count(*) from admin_actions_search((select v from t_ids where k = 'clara'), 'ahmad.ramadhan')) = 1,
                 'search matches the label');
select jt.assert((select target_label from admin_actions_search((select v from t_ids where k = 'clara'), 'ahmad.ramadhan')) like 'Ahmad%',
                 'search returns the label');
reset role;

-- a target id that is not a uuid never aborts the trigger
insert into admin_actions (admin_id, action, target_type, target_id, detail)
  values ((select v from t_ids where k = 'clara'), 'member_fix_major', 'profile',
          'abcdefabcdefabcdefabcdefabcdefabcdef', 'x');
select jt.assert(not has_function_privilege('anon', 'admin_actions_fill_label()', 'execute'), 'anon cannot run the label trigger function');
select jt.assert(not has_function_privilege('authenticated', 'admin_actions_fill_label()', 'execute'), 'signed-in cannot run the label trigger function');
set role anon;
select jt.expect_error(format($q$select * from admin_actions_search(%L)$q$, (select v from t_ids where k = 'dewi')), 'not_admin');
reset role;

rollback;
\o
\echo admin log target checks passed
