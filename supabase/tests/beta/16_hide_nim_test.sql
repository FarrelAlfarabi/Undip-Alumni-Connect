-- NIM is private: other members cannot read it from alumni_profiles, owners and
-- admins get it through profile_nim(). Runs in a transaction that is rolled back.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com');
insert into app_admins (profile_id) values (jt.pid('siti.azizah@example.com')) on conflict do nothing;

create temp table t_nim as select nim from alumni_profiles where email = 'ahmad.ramadhan@example.com';
grant select on t_nim to anon;
select jt.assert((select nim from t_nim) is not null, 'seed has a NIM');

-- ---- the API roles cannot read the column in any form ---------------------
set role anon;
select jt.expect_error($q$select nim from alumni_profiles$q$, 'permission denied');
select jt.expect_error($q$select * from alumni_profiles$q$, 'permission denied');
select jt.expect_error($q$select id from alumni_profiles where nim = '21120112130001'$q$, 'permission denied');
select jt.expect_error($q$select id from alumni_profiles order by nim$q$, 'permission denied');
-- Everything else the app reads still works.
select jt.assert((select count(*) from alumni_profiles where verification_status = 'verified') >= 3, 'rows still readable');
select id, name, email, faculty, major, graduation_year, city, industry, company, current_role from alumni_profiles limit 1;
reset role;

set role authenticated;
select jt.expect_error($q$select nim from alumni_profiles$q$, 'permission denied');
reset role;

-- The owner's own save (UPDATE ... RETURNING) still works with an explicit list.
set role anon;
update alumni_profiles set company = 'Test Co' where id = jt.pid('ahmad.ramadhan@example.com')
  returning id, name, email, company;
reset role;

-- ---- profile_nim: owner and admin only ------------------------------------
set role anon;
select jt.assert(profile_nim(jt.pid('ahmad.ramadhan@example.com'), jt.pid('ahmad.ramadhan@example.com'))
                 = (select nim from t_nim), 'owner sees own NIM');
select jt.assert(profile_nim(jt.pid('siti.azizah@example.com'), jt.pid('ahmad.ramadhan@example.com')) is not null, 'admin sees any NIM');
select jt.assert(profile_nim(jt.pid('bagas.prasetyo@example.com'), jt.pid('ahmad.ramadhan@example.com')) is null, 'another member gets null');
select jt.assert(profile_nim(null, jt.pid('ahmad.ramadhan@example.com')) is null, 'no viewer gets null');
reset role;

-- ---- guard: every other column stays readable ------------------------------
select jt.assert(not exists (
  select 1 from information_schema.columns c
   where c.table_schema = 'public' and c.table_name = 'alumni_profiles'
     and c.column_name <> 'nim'
     and not has_column_privilege('anon', 'public.alumni_profiles', c.column_name, 'select')),
  'every column except nim is readable by anon: a new column needs its own grant');

rollback;
\o
\echo 16_hide_nim_test: ok
