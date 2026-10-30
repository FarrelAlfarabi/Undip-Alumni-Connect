-- Profile bio: a verified member sets their own bio through profile_set_bio(),
-- 200 characters at most, trimmed, empty means none, no control characters.
-- The column cannot be written directly by the app roles. An admin can clear
-- one bio (admin_clear_bio) without touching the account. Deleting an account
-- clears the bio. With require_login on only the owner can change it.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set verification_status = 'verified', user_id = null
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com');
update alumni_profiles set verification_status = 'unverified', user_id = null
  where email = 'bagas.prasetyo@example.com';

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'bagas', jt.pid('bagas.prasetyo@example.com');
create temp table t_names (k text primary key, v text);
grant all on t_names to anon, authenticated;
insert into t_names select 'ahmad', name from alumni_profiles where id = jt.pid('ahmad.ramadhan@example.com');
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

set role anon;

-- Starts empty and is readable by the app roles like the other columns.
select jt.assert((select bio is null from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'starts empty');

-- Set, trim, read back.
select profile_set_bio((select v from t_ids where k = 'ahmad'), '  Suka diskusi karier.  ');
select jt.assert((select bio from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = 'Suka diskusi karier.', 'bio saved and trimmed');

-- Exactly 200 is fine, 201 is not.
select profile_set_bio((select v from t_ids where k = 'ahmad'), repeat('a', 200));
select jt.assert((select char_length(bio) from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = 200, '200 characters allowed');
select jt.expect_error(format($q$select profile_set_bio(%L, repeat('a', 201))$q$, (select v from t_ids where k = 'ahmad')), 'bio_too_long');

-- Empty or blank means no bio.
select profile_set_bio((select v from t_ids where k = 'ahmad'), '   ');
select jt.assert((select bio is null from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'blank becomes null');
select profile_set_bio((select v from t_ids where k = 'ahmad'), E'\n\t \n');
select jt.assert((select bio is null from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'only line breaks becomes null');
select jt.expect_error(format($q$select profile_set_bio(%L, 'a' || U&'\202E' || 'b')$q$, (select v from t_ids where k = 'ahmad')), 'bio_invalid');
select jt.expect_error(format($q$select profile_set_bio(%L, 'a' || U&'\200B' || 'b')$q$, (select v from t_ids where k = 'ahmad')), 'bio_invalid');
select profile_set_bio((select v from t_ids where k = 'ahmad'), 'Halo 👋 café');
select profile_set_bio((select v from t_ids where k = 'ahmad'), null);
select jt.assert((select bio is null from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'null clears the bio');

-- Control characters are refused; a normal line break is kept.
select jt.expect_error(format($q$select profile_set_bio(%L, 'a' || chr(7) || 'b')$q$, (select v from t_ids where k = 'ahmad')), 'bio_invalid');
select profile_set_bio((select v from t_ids where k = 'ahmad'), E'Baris satu\nBaris dua');
select jt.assert((select bio from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = E'Baris satu\nBaris dua', 'line break kept');

-- Unverified or unknown profiles cannot set a bio.
select jt.expect_error(format($q$select profile_set_bio(%L, 'Halo')$q$, (select v from t_ids where k = 'bagas')), 'not_verified');
select jt.expect_error($q$select profile_set_bio(gen_random_uuid(), 'Halo')$q$, 'not_verified|not_found');

-- The app roles cannot write the column directly (only through the function).
select jt.expect_error(format($q$update alumni_profiles set bio = 'langsung' where id = %L$q$, (select v from t_ids where k = 'ahmad')), 'can be updated');
-- Other columns the editor saves still work.
update alumni_profiles set industry = 'Banking' where id = (select v from t_ids where k = 'ahmad');

-- Not callable through "public".
select jt.assert(not has_function_privilege('public', 'profile_set_bio(uuid, text)', 'execute'), 'public cannot set a bio');
select jt.assert(has_function_privilege('anon', 'profile_set_bio(uuid, text)', 'execute'), 'anon can call it');
select jt.assert(not has_function_privilege('public', 'admin_clear_bio(uuid, uuid)', 'execute'), 'public cannot clear a bio');

-- Admin clears one bio, and only an admin can.
select jt.expect_error(format($q$select admin_clear_bio(%L, %L)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select admin_clear_bio((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad'));
select jt.assert((select bio is null from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'admin cleared the bio');
select jt.assert((select name from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = (select v from t_names where k = 'ahmad'), 'account untouched by Hapus bio');
select jt.expect_error(format($q$select admin_clear_bio(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'clara')), 'not_found');

-- Deleting the account clears the bio.
select profile_set_bio((select v from t_ids where k = 'siti'), 'Bio yang harus hilang');
select account_delete((select v from t_ids where k = 'siti'));
reset role;
select jt.assert((select bio is null from alumni_profiles where id = (select v from t_ids where k = 'siti')), 'account deletion clears the bio');

-- ---- require_login on: only the owner ------------------------------------
insert into t_ids select 'uahmad', gen_random_uuid();
insert into auth.users (id, email) values ((select v from t_ids where k = 'uahmad'), 'ahmad.ramadhan@example.com');
update app_settings set value = 'on' where key = 'require_login';

set role anon;
select jt.expect_error(format($q$select profile_set_bio(%L, 'Halo')$q$, (select v from t_ids where k = 'ahmad')), 'not_signed_in');
reset role;

select set_config('test.uid', (select v::text from t_ids where k = 'uahmad'), true);
set role authenticated;
select claim_alumni_profile();
select profile_set_bio((select v from t_ids where k = 'ahmad'), 'Bio saya');
select jt.assert((select bio from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = 'Bio saya', 'owner sets own bio');
select jt.expect_error(format($q$select profile_set_bio(%L, 'bukan bio kamu')$q$, (select v from t_ids where k = 'clara')), 'forbidden|not_signed_in|not_your');
reset role;

rollback;
\o
\echo profile bio checks passed
