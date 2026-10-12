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

-- Soft-deleted profiles, empty input and duplicate emails are refused.
update alumni_profiles set deleted_at = now() where email = 'bagas.prasetyo@example.com';
select jt.expect_error($q$select add_app_admin('bagas.prasetyo@example.com')$q$, 'no_profile_with_email');
select jt.expect_error($q$select add_app_admin(null)$q$, 'no_profile_with_email');
update alumni_profiles set email = 'CLARA.putri@example.com' where email = 'siti.azizah@example.com';
select jt.expect_error($q$select add_app_admin('clara.putri@example.com')$q$, 'more_than_one_profile_with_email');
select jt.assert(jt.count_of('select 1 from app_admins') = 0, 'refused calls added nobody');

-- Note and added_at show in the list.
select add_app_admin('ahmad.ramadhan@example.com', 'Ahmad again');
select jt.assert((select note is not null and added_at is not null from list_app_admins()), 'list shows note and added_at');
select remove_app_admin('ahmad.ramadhan@example.com');
select jt.assert(jt.count_of('select 1 from list_app_admins()') = 0, 'empty list when no admins');

-- No app role (and not the service key) has execute.
select jt.assert(not has_function_privilege(r, f, 'execute'), r || ' cannot execute ' || f)
  from unnest(array['anon','authenticated','service_role']) r,
       unnest(array['add_app_admin(text,text)','remove_app_admin(text)','list_app_admins()']) f;

-- The app roles cannot call any of them.
set role anon;
select jt.expect_error($q$select add_app_admin('siti.azizah@example.com')$q$, 'permission denied');
select jt.expect_error($q$select remove_app_admin('siti.azizah@example.com')$q$, 'permission denied');
select jt.expect_error($q$select * from list_app_admins()$q$, 'permission denied');
reset role;
set role authenticated;
select jt.expect_error($q$select add_app_admin('siti.azizah@example.com')$q$, 'permission denied');
select jt.expect_error($q$select remove_app_admin('siti.azizah@example.com')$q$, 'permission denied');
select jt.expect_error($q$select * from list_app_admins()$q$, 'permission denied');
reset role;
select jt.assert(jt.count_of('select 1 from app_admins') = 0, 'denied calls changed nothing');

rollback;
\o
\echo admin helper checks passed
