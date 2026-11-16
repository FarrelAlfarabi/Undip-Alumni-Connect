-- NIM is gone (20261116180000_remove_nim): no column, no unique key, no
-- function that reads it, and the two functions that named it still work.
-- Runs in a transaction that is rolled back.
\set ON_ERROR_STOP on
\o /dev/null
begin;

select jt.assert(not exists (select 1 from information_schema.columns
                              where table_schema = 'public' and table_name = 'alumni_profiles'
                                and column_name = 'nim'), 'no nim column');
select jt.assert(not exists (select 1 from pg_constraint where conname = 'alumni_profiles_nim_key'), 'no nim unique key');
select jt.assert(to_regprocedure('public.profile_nim(uuid,uuid)') is null, 'profile_nim is dropped');
select jt.assert(to_regprocedure('public.provision_alumni_accounts()') is null, 'provision_alumni_accounts is dropped');
select jt.assert(not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                              where n.nspname = 'public' and p.prosrc ~* '\mnim\M'), 'no public function names nim');
select jt.assert(not exists (select 1 from pg_policies where coalesce(qual, '') || coalesce(with_check, '') ~* '\mnim\M'), 'no policy names nim');
select jt.assert(exists (select 1 from pg_constraint where conname = 'alumni_profiles_email_key'), 'email is still the unique key');
select jt.assert((select prosrc from pg_proc where oid = to_regprocedure('public.account_delete(uuid)')) ~ 'assert_caller', 'account_delete still checks the caller');
select jt.assert(has_function_privilege('anon', 'public.account_delete(uuid)', 'execute')
             and has_function_privilege('authenticated', 'public.account_delete(uuid)', 'execute'), 'app can still delete its account');

-- Asking for the column fails because it is not there (16_profile_city_edit
-- checks the own-profile save still works with the new trigger).
set role anon;
select jt.expect_error($q$select nim from alumni_profiles$q$, 'does not exist');
reset role;

rollback;
\o
\echo remove nim checks passed
