-- Admin "Ubah profil anggota": an admin edits only the fields a member can edit
-- in their own profile (role, industry, company, city, bio, LinkedIn). Not an
-- admin: refused. Protected fields (NIM, email, name, status, ...): refused.
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
update alumni_profiles set bio = 'Bio lama', city = 'Semarang' where id = (select v from t_ids where k = 'ahmad');

set role anon;
select jt.assert(not has_function_privilege('public', 'admin_update_profile(uuid, uuid, jsonb)', 'execute'), 'public cannot edit a profile');

-- Not an admin: refused, nothing changes.
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"bio":"Diubah"}')$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.assert((select bio from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = 'Bio lama', 'non-admin changed nothing');

-- Admin edits every allowed field.
select admin_update_profile((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'),
  '{"current_role":"Analis","industry":"Perbankan","company":"Bank Contoh","city":"Jakarta","bio":"Bio baru","linkedin_url":"linkedin.com/in/ahmad"}');
select jt.assert((select ("current_role" = 'Analis' and industry = 'Perbankan' and company = 'Bank Contoh'
                          and current_employer = 'Bank Contoh' and city = 'Jakarta' and bio = 'Bio baru'
                          and linkedin_url = 'https://linkedin.com/in/ahmad')
                    from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'admin changed the allowed fields');

-- Only the keys sent change; blank clears the optional ones.
select admin_update_profile((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), '{"bio":"  ","linkedin_url":""}');
select jt.assert((select bio is null and linkedin_url is null and city = 'Jakarta' and company = 'Bank Contoh'
                    from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'blank clears bio and link only');

-- Protected fields are refused, even mixed with allowed ones, and nothing is saved.
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"nim":"24060000000"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'protected_field');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"user_id":"00000000-0000-0000-0000-000000000000"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'protected_field');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"verification_status":"verified"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'protected_field');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"major":"Manajemen"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'protected_field');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"city":"Bandung","subscription_status":"x"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'protected_field');
select jt.assert((select city = 'Jakarta' from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'protected attempt saved nothing');

-- Bad values, empty change, unknown profile.
select jt.expect_error(format($q$select admin_update_profile(%L, %L, %L)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'), '{"bio":"' || repeat('a', 201) || '"}'), 'invalid_input');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"linkedin_url":"https://example.com/x"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'invalid_input');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"city":5}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'invalid_input');
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'invalid_input');
select jt.expect_error(format($q$select admin_update_profile(%L, gen_random_uuid(), '{"city":"X"}')$q$, (select v from t_ids where k = 'clara')), 'not_found');

-- Member search: admin only, by name, no NIM column.
select jt.expect_error(format($q$select * from admin_members_search(%L, 'ahmad')$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.assert((select count(*) from admin_members_search((select v from t_ids where k = 'clara'), 'fauzan')) = 1, 'admin finds a member by name');
select jt.assert((select count(*) from admin_members_search((select v from t_ids where k = 'clara'), '%')) = 0, 'percent is not a wildcard');
select jt.assert((select count(*) from admin_members_search((select v from t_ids where k = 'clara'))) between 1 and 1000, 'empty search lists members');
select jt.assert(not exists (select 1 from information_schema.routines r join information_schema.parameters q on q.specific_name = r.specific_name
                              where r.routine_name = 'admin_members_search' and q.parameter_mode = 'OUT' and q.parameter_name = 'nim'), 'search never returns NIM');

-- The change is written to the admin log.
select jt.assert((select detail = 'bio, city, company, current_role, industry, linkedin_url' from admin_actions_list((select v from t_ids where k = 'clara')) where action = 'edit_profile' and target_id = (select v::text from t_ids where k = 'ahmad') order by created_at limit 1), 'log holds field names only');
select jt.assert((select count(*) from admin_actions_list((select v from t_ids where k = 'clara')) where action = 'edit_profile' and target_id = (select v::text from t_ids where k = 'ahmad')) >= 1, 'edit is logged');
reset role;

-- With require_login on, an admin id that is not the signed-in person is refused.
insert into t_ids select 'uclara', gen_random_uuid();
insert into auth.users (id, email) values ((select v from t_ids where k = 'uclara'), 'clara.putri@example.com');
update app_settings set value = 'on' where key = 'require_login';
set role anon;
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"city":"Medan"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'not_signed_in|not_admin');
select jt.expect_error(format($q$select * from admin_members_search(%L, 'ahmad')$q$, (select v from t_ids where k = 'clara')), 'not_signed_in|not_admin');
reset role;
-- Signed in as someone else (not clara): refused for both functions.
select set_config('test.uid', (select gen_random_uuid()::text), true);
set role anon;
select jt.expect_error(format($q$select admin_update_profile(%L, %L, '{"city":"Medan"}')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'not_signed_in|not_admin');
select jt.expect_error(format($q$select * from admin_members_search(%L, 'ahmad')$q$, (select v from t_ids where k = 'clara')), 'not_signed_in|not_admin');
reset role;

rollback;
\o
\echo admin edit profile checks passed
