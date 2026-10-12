-- Admin helpers: add_app_admin, remove_app_admin, list_app_admins.
-- The owner runs them from the dashboard. The app roles must not be able to.
\set ON_ERROR_STOP on
\o /dev/null
begin;

-- Adding by email, with stray spaces and capitals.
select jt.assert(add_app_admin('  Ahmad.Ramadhan@Example.com ', 'Ahmad') = 'added', 'first add says added');
select jt.assert(is_app_admin(jt.pid('ahmad.ramadhan@example.com')), 'added profile is admin');
select jt.assert((select note from app_admins where profile_id = jt.pid('ahmad.ramadhan@example.com')) = 'Ahmad', 'note stored');

-- Adding again is harmless.
select jt.assert(add_app_admin('ahmad.ramadhan@example.com') = 'already_admin', 'second add says already_admin');
select jt.assert(jt.count_of('select 1 from app_admins') = 1, 'still one admin row');

-- An email with no profile gives a clear error, not a silent nothing.
select jt.expect_error($q$select add_app_admin('nobody@example.com')$q$, 'no_profile_with_email');
select jt.expect_error($q$select add_app_admin('   ')$q$, 'no_profile_with_email');

-- The list shows who is admin.
select jt.assert((select count(*) from list_app_admins() where email = 'ahmad.ramadhan@example.com') = 1, 'list shows the admin');

-- Removing.
select jt.assert(remove_app_admin('AHMAD.RAMADHAN@example.com') = 'removed', 'remove says removed');
select jt.assert(not is_app_admin(jt.pid('ahmad.ramadhan@example.com')), 'removed profile is not admin');
select jt.assert(remove_app_admin('ahmad.ramadhan@example.com') = 'not_admin', 'remove again says not_admin');

-- The app roles cannot call any of them.
set role anon;
select jt.expect_error($q$select add_app_admin('siti.azizah@example.com')$q$, 'permission denied');
select jt.expect_error($q$select remove_app_admin('siti.azizah@example.com')$q$, 'permission denied');
select jt.expect_error($q$select * from list_app_admins()$q$, 'permission denied');
reset role;
set role authenticated;
select jt.expect_error($q$select add_app_admin('siti.azizah@example.com')$q$, 'permission denied');
reset role;

rollback;
\o
\echo admin helper checks passed
