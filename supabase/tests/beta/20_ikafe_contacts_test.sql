-- Kontak Ikafe: everyone reads active rows, only an admin writes.
-- All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

set role anon;
-- The five example rows are readable, and hidden ones are not.
select jt.assert((select count(*) from ikafe_contacts) = 5, 'examples are readable');
-- The table is closed to writes, for admins too.
select jt.expect_error($q$insert into ikafe_contacts (kind, label, value) values ('email', 'x', 'y')$q$, 'permission denied|row-level security');
select jt.expect_error($q$update ikafe_contacts set label = 'x'$q$, 'permission denied');
select jt.expect_error($q$delete from ikafe_contacts$q$, 'permission denied');
-- Not an admin: refused.
select jt.expect_error(format($q$select * from admin_ikafe_contact_list(%L)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error(format($q$select admin_ikafe_contact_save(%L, null, 'email', 'L', 'a@b.id', 1, true)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error(format($q$select admin_ikafe_contact_delete(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error($q$select admin_ikafe_contact_save(null, null, 'email', 'L', 'a@b.id', 1, true)$q$, 'not_admin');
-- Admin: input rules.
select jt.expect_error(format($q$select admin_ikafe_contact_save(%L, null, 'fax', 'L', 'v', 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_ikafe_contact_save(%L, null, 'email', '  ', 'v', 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_ikafe_contact_save(%L, null, 'email', 'L', null, 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_ikafe_contact_save(%L, null, 'email', %L, 'v', 1, true)$q$, (select v from t_ids where k = 'clara'), repeat('x', 61)), 'invalid_input');
select jt.expect_error(format($q$select admin_ikafe_contact_save(%L, null, 'email', 'L', %L, 1, true)$q$, (select v from t_ids where k = 'clara'), repeat('x', 201)), 'invalid_input');
select jt.expect_error(format($q$select admin_ikafe_contact_save(%L, gen_random_uuid(), 'email', 'L', 'v', 1, true)$q$, (select v from t_ids where k = 'clara')), 'not_found');
select jt.expect_error(format($q$select admin_ikafe_contact_delete(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'clara')), 'not_found');
select jt.assert((select count(*) from ikafe_contacts) = 5, 'refused calls wrote nothing');

-- Admin adds a hidden row: trimmed, not visible to readers, visible to admin.
select admin_ikafe_contact_save((select v from t_ids where k = 'clara'), null, 'website', '  Web ', ' ikafe.id ', 9, false);
select jt.assert((select count(*) from ikafe_contacts) = 5, 'hidden row not readable');
select jt.assert((select count(*) from admin_ikafe_contact_list((select v from t_ids where k = 'clara'))) = 6, 'admin sees hidden');
select jt.assert((select count(*) from admin_ikafe_contact_list((select v from t_ids where k = 'clara')) where label = 'Web' and value = 'ikafe.id' and not active) = 1, 'trimmed and hidden');
-- Admin shows it, changes it, then deletes it.
create temp table t_new as select id from admin_ikafe_contact_list((select v from t_ids where k = 'clara')) where label = 'Web';
grant select on t_new to anon;
select admin_ikafe_contact_save((select v from t_ids where k = 'clara'), (select id from t_new), 'website', 'Web Ikafe', 'ikafe.id', 9, true);
select jt.assert((select count(*) from ikafe_contacts where label = 'Web Ikafe') = 1, 'shown and renamed');
select admin_ikafe_contact_delete((select v from t_ids where k = 'clara'), (select id from t_new));
select jt.assert((select count(*) from ikafe_contacts) = 5, 'deleted');
reset role;

rollback;
\o
\echo ikafe contacts checks passed
