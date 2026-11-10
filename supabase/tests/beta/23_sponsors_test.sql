-- Sponsors: members read only live rows, only an admin writes, and more than
-- one sponsor can be live. All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

set role anon;
select jt.assert((select count(*) from sponsors) = 0, 'no sponsor to start with');
-- The table is closed to writes, for admins too.
select jt.expect_error($q$insert into sponsors (name, image_url, link_url) values ('x', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/x.jpg', 'https://a.b')$q$, 'permission denied|row-level security');
select jt.expect_error($q$update sponsors set name = 'x'$q$, 'permission denied');
select jt.expect_error($q$delete from sponsors$q$, 'permission denied');
-- Not an admin: refused.
select jt.expect_error(format($q$select * from admin_sponsor_list(%L)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b', null, null, 1, true)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error(format($q$select admin_sponsor_delete(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error($q$select admin_sponsor_save(null, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b', null, null, 1, true)$q$, 'not_admin');

-- Admin: input rules.
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, '  ', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b', null, null, 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://a.b/other/a.jpg', 'https://a.b', null, null, 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'http://a.b', null, null, 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'javascript:alert(1)', null, null, 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b', '2026-12-31', '2026-12-01', 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b', null, null, 1000, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, gen_random_uuid(), 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b', null, null, 1, true)$q$, (select v from t_ids where k = 'clara')), 'not_found');
select jt.expect_error(format($q$select admin_sponsor_delete(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'clara')), 'not_found');
select jt.assert((select count(*) from admin_sponsor_list((select v from t_ids where k = 'clara'))) = 0, 'refused calls wrote nothing');

select jt.expect_error(format($q$select admin_sponsor_save(%L, null, %L, 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b', null, null, 1, true)$q$, (select v from t_ids where k = 'clara'), repeat('x', 81)), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://evil.example.com/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b', null, null, 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg?x=1', 'https://a.b', null, null, 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b/a b', null, null, 1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', 'https://a.b', null, null, -1, true)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_sponsor_save(%L, null, 'A', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', %L, null, null, 1, true)$q$, (select v from t_ids where k = 'clara'), 'https://a.b/' || repeat('x', 500)), 'invalid_input');

-- Admin adds three sponsors: two live now (one with no dates, one with a
-- window around today), one hidden, one not started, one ended.
select admin_sponsor_save((select v from t_ids where k = 'clara'), null, '  Bank A ', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/a.jpg', ' https://a.example.com ', null, null, 2, true);
select admin_sponsor_save((select v from t_ids where k = 'clara'), null, 'Toko B', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/b.jpg', 'https://b.example.com', (now() at time zone 'Asia/Jakarta')::date - 5, (now() at time zone 'Asia/Jakarta')::date + 5, 1, true);
select admin_sponsor_save((select v from t_ids where k = 'clara'), null, 'Hidden C', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/c.jpg', 'https://c.example.com', null, null, 3, false);
select admin_sponsor_save((select v from t_ids where k = 'clara'), null, 'Future D', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/d.jpg', 'https://d.example.com', (now() at time zone 'Asia/Jakarta')::date + 10, null, 4, true);
select admin_sponsor_save((select v from t_ids where k = 'clara'), null, 'Edge F', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/f.jpg', 'https://f.example.com', (now() at time zone 'Asia/Jakarta')::date, (now() at time zone 'Asia/Jakarta')::date, 9, true);
select admin_sponsor_save((select v from t_ids where k = 'clara'), null, 'Ended E', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/e.jpg', 'https://e.example.com', null, (now() at time zone 'Asia/Jakarta')::date - 10, 5, true);

select jt.assert((select count(*) from admin_sponsor_list((select v from t_ids where k = 'clara'))) = 6, 'admin sees all six');
select jt.assert((select count(*) from sponsors) = 3, 'members read only the live rows (edge dates count)');
select jt.assert((select count(*) from home_sponsors()) = 3, 'home_sponsors gives the live rows');
select jt.assert((select string_agg(name, ',' order by rank) from sponsors) = 'Toko B,Bank A,Edge F', 'several sponsors at once, trimmed');
select jt.assert((select array_agg(name) from home_sponsors()) = array['Toko B', 'Bank A', 'Edge F'], 'carousel order follows rank');
select jt.assert((select link_url from home_sponsors() where name = 'Bank A') = 'https://a.example.com', 'link trimmed');

-- Admin hides one, changes another, deletes one.
create temp table t_new as select id, name from admin_sponsor_list((select v from t_ids where k = 'clara'));
grant select on t_new to anon;
select admin_sponsor_save((select v from t_ids where k = 'clara'), (select id from t_new where name = 'Toko B'), 'Toko B', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/b.jpg', 'https://b.example.com', null, null, 1, false);
select jt.assert((select count(*) from home_sponsors()) = 2, 'hidden sponsor leaves the carousel');
select admin_sponsor_save((select v from t_ids where k = 'clara'), (select id from t_new where name = 'Hidden C'), 'Show C', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/c.jpg', 'https://c.example.com', null, null, 0, true);
select jt.assert((select array_agg(name) from home_sponsors()) = array['Show C', 'Bank A', 'Edge F'], 'shown again and first by rank');
select admin_sponsor_delete((select v from t_ids where k = 'clara'), (select id from t_new where name = 'Hidden C'));
select jt.assert((select count(*) from admin_sponsor_list((select v from t_ids where k = 'clara'))) = 5, 'deleted');
reset role;
-- Same refusals as the signed-in role.
set role authenticated;
select jt.expect_error($q$insert into sponsors (name, image_url, link_url) values ('x', 'https://x.supabase.co/storage/v1/object/public/sponsor-images/x.jpg', 'https://a.b')$q$, 'permission denied|row-level security');
select jt.expect_error($q$delete from sponsors$q$, 'permission denied');
reset role;

rollback;
\o
\echo sponsors checks passed
