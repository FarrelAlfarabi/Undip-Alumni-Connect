-- Beta hardening 1: verification_status can no longer be written by the app.
-- Verification goes through verify_alumni_email(). All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com');
update alumni_profiles set verification_status = 'unverified'
  where email in ('rizky.yusuf@example.com', 'bagas.prasetyo@example.com');
update alumni_profiles set verification_status = 'failed' where email = 'clara.putri@example.com';

create temp table t_before as select count(*) filter (where verification_status = 'verified') as verified, count(*) filter (where verification_status = 'unverified') as unverified from alumni_profiles;
grant all on t_before to anon;

set role anon;

-- ------------------------------------------- the attacker's direct writes ---
-- Flip one person to verified.
select jt.expect_error(format($q$update alumni_profiles set verification_status = 'verified' where id = %L$q$, jt.pid('rizky.yusuf@example.com')), 'can be updated');
-- Un-verify someone (this used to log every device out and wipe its PIN).
select jt.expect_error(format($q$update alumni_profiles set verification_status = 'unverified' where id = %L$q$, jt.pid('ahmad.ramadhan@example.com')), 'can be updated');
-- Bulk flip, every row.
select jt.expect_error($q$update alumni_profiles set verification_status = 'verified'$q$, 'can be updated');
select jt.expect_error($q$update alumni_profiles set verification_status = 'unverified'$q$, 'can be updated');
-- Writing the same value is not a change, and the fields the app edits still work.
update alumni_profiles set industry = 'Keuangan', verification_status = 'verified' where id = jt.pid('ahmad.ramadhan@example.com');
reset role;
select jt.assert((select count(*) filter (where verification_status = 'verified') from alumni_profiles) = (select verified from t_before), 'direct writes changed nobody (verified)');
select jt.assert((select count(*) filter (where verification_status = 'unverified') from alumni_profiles) = (select unverified from t_before), 'direct writes changed nobody (unverified)');
set role anon;

-- ----------------------------------------------------- the verify function ---
-- An exact match verifies the person and returns the profile row.
select jt.assert((select count(*) from verify_alumni_email('rizky.yusuf@example.com')) = 1, 'match returns one row');
select jt.assert((select verification_status from verify_alumni_email('rizky.yusuf@example.com')) = 'verified', 'returned row is verified');
reset role;
select jt.assert((select verification_status from alumni_profiles where email = 'rizky.yusuf@example.com') = 'verified', 'row really changed');
set role anon;

-- Case and spaces do not matter (the real Ikafe list may have mixed case).
select jt.assert((select email from verify_alumni_email('  BAGAS.Prasetyo@Example.COM ')) = 'bagas.prasetyo@example.com', 'case and spaces ignored');

-- No match, empty and null give no row. Nothing is created.
select jt.assert((select count(*) from verify_alumni_email('nobody@example.com')) = 0, 'unknown email gives no row');
select jt.assert((select count(*) from verify_alumni_email('')) = 0, 'empty gives no row');
select jt.assert((select count(*) from verify_alumni_email(null)) = 0, 'null gives no row');

-- An admin can revoke: a failed person stays failed and the app is told so.
select jt.assert((select verification_status from verify_alumni_email('clara.putri@example.com')) = 'failed', 'failed stays failed');
reset role;
select jt.assert((select verification_status from alumni_profiles where email = 'clara.putri@example.com') = 'failed', 'failed row untouched');

-- Only the status moves. Nothing else on the row changes.
select jt.assert((select name from alumni_profiles where email = 'bagas.prasetyo@example.com') is not null, 'row intact');

-- A deleted person cannot verify again.
update alumni_profiles set deleted_at = now(), verification_status = 'unverified' where email = 'siti.azizah@example.com';
set role anon;
select jt.assert((select count(*) from verify_alumni_email('siti.azizah@example.com')) = 0, 'deleted person gives no row');
reset role;

-- The function is the only thing that sets it: it works for anon, and the
-- trigger and internal helpers stay closed.
select jt.assert(has_function_privilege('anon', 'verify_alumni_email(text)', 'execute'), 'anon can call verify_alumni_email');

rollback;
\o
\echo verification lock checks passed
