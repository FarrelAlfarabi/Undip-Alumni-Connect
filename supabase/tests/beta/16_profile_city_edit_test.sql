-- The profile editor saves city with the job fields. The column lock used to
-- reject any city change, so the save failed with a generic error.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set city = null where email = 'ahmad.ramadhan@example.com';
update alumni_profiles set verification_status = 'unverified' where email = 'rizky.yusuf@example.com';
set role anon;

-- City can be set and changed together with the employment fields.
update alumni_profiles set "current_role" = 'Manager', company = 'PT ABC', current_employer = 'PT ABC', industry = 'Keuangan', city = 'Jakarta'
  where id = jt.pid('ahmad.ramadhan@example.com');
update alumni_profiles set city = 'Semarang' where id = jt.pid('ahmad.ramadhan@example.com');
reset role;
select jt.assert((select city from alumni_profiles where email = 'ahmad.ramadhan@example.com') = 'Semarang', 'city changed');
set role anon;

-- Everything else stays locked.
select jt.expect_error(format($q$update alumni_profiles set nim = 'X1' where id = %L$q$, jt.pid('ahmad.ramadhan@example.com')), 'can be updated');
select jt.expect_error(format($q$update alumni_profiles set name = 'Other' where id = %L$q$, jt.pid('ahmad.ramadhan@example.com')), 'can be updated');
select jt.expect_error(format($q$update alumni_profiles set email = 'x@example.com' where id = %L$q$, jt.pid('ahmad.ramadhan@example.com')), 'can be updated');
select jt.expect_error(format($q$update alumni_profiles set verification_status = 'verified' where id = %L$q$, jt.pid('rizky.yusuf@example.com')), 'can be updated');
reset role;

rollback;
\o
\echo profile city edit checks passed
