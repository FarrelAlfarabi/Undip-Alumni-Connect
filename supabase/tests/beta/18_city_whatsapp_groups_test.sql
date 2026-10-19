-- City WhatsApp groups: closed table, verified members only, WhatsApp links only.
-- All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');

create temp table t_before as select count(*) as n from city_whatsapp_groups;
grant select on t_before to anon;

set role anon;
-- The table is closed to direct reads and writes.
select jt.expect_error($q$select * from city_whatsapp_groups$q$, 'permission denied');
select jt.expect_error($q$insert into city_whatsapp_groups (city, invite_url) values ('Semarang', 'https://chat.whatsapp.com/AbCdEfGhIjKl')$q$, 'permission denied');
select jt.expect_error($q$update city_whatsapp_groups set invite_url = 'https://chat.whatsapp.com/AbCdEfGhIjKl'$q$, 'permission denied');
select jt.expect_error($q$delete from city_whatsapp_groups$q$, 'permission denied');
reset role;
set role authenticated;
select jt.expect_error($q$select * from city_whatsapp_groups$q$, 'permission denied');
reset role;
set role anon;
-- Unknown or missing caller.
select jt.expect_error($q$select * from city_whatsapp_groups_list(gen_random_uuid())$q$, 'not_verified');
select jt.expect_error($q$select city_whatsapp_group_set(null, 'Semarang', 'https://chat.whatsapp.com/AbCdEfGhIjKl')$q$, 'not_verified');
select jt.expect_error($q$select city_whatsapp_group_set(gen_random_uuid(), 'Semarang', 'https://chat.whatsapp.com/AbCdEfGhIjKl')$q$, 'not_verified');
-- Input rules (valid caller).
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Semarang', 'https://evil.example.com/AbCdEfGhIjKl')$q$, (select v from t_ids where k = 'siti')), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Semarang', 'http://chat.whatsapp.com/AbCdEfGhIjKl')$q$, (select v from t_ids where k = 'siti')), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Semarang', 'https://chat.whatsapp.com/AbCd')$q$, (select v from t_ids where k = 'siti')), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Semarang', 'https://chat.whatsapp.com/AbCdEfGhIjKl/../x')$q$, (select v from t_ids where k = 'siti')), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, '  ', 'https://chat.whatsapp.com/AbCdEfGhIjKl')$q$, (select v from t_ids where k = 'siti')), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, %L, 'https://chat.whatsapp.com/AbCdEfGhIjKl')$q$, (select v from t_ids where k = 'siti'), repeat('x', 81)), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Semarang', null)$q$, (select v from t_ids where k = 'siti')), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, E'Sema\trang', 'https://chat.whatsapp.com/AbCdEfGhIjKl')$q$, (select v from t_ids where k = 'siti')), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Semarang', E'https://chat.whatsapp.com/AbCdEfGhIjKl\nx')$q$, (select v from t_ids where k = 'siti')), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Semarang', 'https://chat.whatsapp.com/%s')$q$, (select v from t_ids where k = 'siti'), repeat('a', 9)), 'invalid_input');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Semarang', 'https://chat.whatsapp.com/%s')$q$, (select v from t_ids where k = 'siti'), repeat('a', 41)), 'invalid_input');
reset role;
select jt.assert((select count(*) from city_whatsapp_groups) = (select n from t_before), 'refused calls wrote nothing');

-- Boundaries are accepted: 10 and 40 character codes, 1 and 80 character cities.
set role anon;
select city_whatsapp_group_set((select v from t_ids where k = 'siti'), 'X', 'https://chat.whatsapp.com/' || repeat('a', 10));
select city_whatsapp_group_set((select v from t_ids where k = 'siti'), repeat('y', 80), 'https://chat.whatsapp.com/' || repeat('b', 40));
reset role;
select jt.assert((select count(*) from city_whatsapp_groups) = 2, 'boundary values stored');
delete from city_whatsapp_groups;

-- A verified member sets a link (trimmed), another member sees it, and can replace it.
set role anon;
select city_whatsapp_group_set((select v from t_ids where k = 'siti'), ' Semarang ', ' https://chat.whatsapp.com/AbCdEfGhIjKl ');
select jt.assert((select count(*) from city_whatsapp_groups_list((select v from t_ids where k = 'clara')) where city = 'Semarang' and invite_url = 'https://chat.whatsapp.com/AbCdEfGhIjKl') = 1, 'another member sees the trimmed link');
select city_whatsapp_group_set((select v from t_ids where k = 'clara'), 'Semarang', 'https://chat.whatsapp.com/ZzYyXxWwVvUu');
select jt.assert((select count(*) from city_whatsapp_groups_list((select v from t_ids where k = 'siti')) where city = 'Semarang') = 1, 'still one row per city');
select city_whatsapp_group_set((select v from t_ids where k = 'clara'), 'SEMARANG', 'https://chat.whatsapp.com/ZzYyXxWwVvUu');
select jt.assert((select count(*) from city_whatsapp_groups_list((select v from t_ids where k = 'siti')) where lower(city) = 'semarang') = 1, 'a different spelling of the case does not add a row');
select jt.assert((select invite_url from city_whatsapp_groups_list((select v from t_ids where k = 'siti')) where city = 'Semarang') = 'https://chat.whatsapp.com/ZzYyXxWwVvUu', 'replaced');
reset role;
select jt.assert((select set_by from city_whatsapp_groups where city = 'Semarang') = (select v from t_ids where k = 'clara'), 'set_by is the last editor');

-- Unverified and suspended members are refused.
update alumni_profiles set suspended_at = now() where id = (select v from t_ids where k = 'clara');
set role anon;
select jt.expect_error(format($q$select * from city_whatsapp_groups_list(%L)$q$, (select v from t_ids where k = 'clara')), 'not_verified');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Jakarta', 'https://chat.whatsapp.com/AbCdEfGhIjKl')$q$, (select v from t_ids where k = 'clara')), 'not_verified');
reset role;

update alumni_profiles set verification_status = 'unverified' where id = (select v from t_ids where k = 'siti');
set role anon;
select jt.expect_error(format($q$select * from city_whatsapp_groups_list(%L)$q$, (select v from t_ids where k = 'siti')), 'not_verified');
select jt.expect_error(format($q$select city_whatsapp_group_set(%L, 'Jakarta', 'https://chat.whatsapp.com/AbCdEfGhIjKl')$q$, (select v from t_ids where k = 'siti')), 'not_verified');
reset role;

rollback;
\o
\echo city whatsapp groups checks passed
