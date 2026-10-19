-- Admin announcements: only an admin can post; the table stays closed.
-- All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

create temp table t_before as select count(*) as n from announcements;
grant select on t_before to anon;

set role anon;
-- The table itself is closed to writes, for admins too.
select jt.expect_error($q$insert into announcements (title, body) values ('x', 'y')$q$, 'row-level security|permission denied');
-- With no update/delete policy these match zero rows instead of raising.
update announcements set title = 'x';
delete from announcements;
-- Not an admin: refused, nothing written.
select jt.expect_error(format($q$select admin_announcement_create(%L, 'Judul', 'Isi')$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error(format($q$select * from admin_announcement_list(%L)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error($q$select admin_announcement_create(gen_random_uuid(), 'Judul', 'Isi')$q$, 'not_admin');
select jt.expect_error($q$select admin_announcement_create(null, 'Judul', 'Isi')$q$, 'not_admin');
-- Admin: input rules.
select jt.expect_error(format($q$select admin_announcement_create(%L, '  ', 'Isi')$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_announcement_create(%L, E'\n\t ', 'Isi')$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_announcement_create(%L, 'Judul', null)$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
select jt.expect_error(format($q$select admin_announcement_create(%L, %L, 'Isi')$q$, (select v from t_ids where k = 'clara'), repeat('x', 121)), 'invalid_input');
select jt.expect_error(format($q$select admin_announcement_create(%L, 'Judul', %L)$q$, (select v from t_ids where k = 'clara'), repeat('x', 2001)), 'invalid_input');
reset role;
select jt.assert((select count(*) from announcements where title in ('Judul', 'x')) = 0, 'refused calls wrote nothing');
select jt.assert((select count(*) from announcements) = (select n from t_before), 'direct update/delete changed nothing');

-- Admin posts: trimmed, posted_by is the admin, everyone can read it.
set role anon;
select admin_announcement_create((select v from t_ids where k = 'clara'), '  Reuni Akbar ', ' Sabtu depan ');
select jt.assert((select count(*) from announcements where title = 'Reuni Akbar' and body = 'Sabtu depan' and posted_by = (select v from t_ids where k = 'clara')) = 1, 'posted, trimmed, attributed');
select jt.assert((select count(*) from admin_announcement_list((select v from t_ids where k = 'clara')) where title = 'Reuni Akbar' and posted_by_name is not null) = 1, 'admin list shows it with the poster');
select jt.assert((select count(*) from announcements where title = 'Reuni Akbar') = 1, 'everyone can read it');
reset role;

-- The boundary lengths are accepted.
set role anon;
select admin_announcement_create((select v from t_ids where k = 'clara'), repeat('x', 120), repeat('y', 2000));
reset role;
select jt.assert((select count(*) from announcements where char_length(title) = 120 and char_length(body) = 2000) = 1, 'boundary lengths stored');

-- Real login on: a signed-in non-admin quoting an admin's id is refused.
alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;
create temp table t_u (v uuid);
grant all on t_u to anon, authenticated;
insert into t_u values (gen_random_uuid());
insert into auth.users (id, email) values ((select v from t_u), 'siti.azizah@example.com');
update alumni_profiles set user_id = (select v from t_u) where id = (select v from t_ids where k = 'siti');
update app_settings set value = 'on' where key = 'require_login';
select set_config('test.uid', (select v::text from t_u), false);
set role authenticated;
select jt.expect_error(format($q$select admin_announcement_create(%L, 'Palsu', 'Isi')$q$, (select v from t_ids where k = 'clara')), 'not_admin');
select jt.expect_error(format($q$select * from admin_announcement_list(%L)$q$, (select v from t_ids where k = 'clara')), 'not_admin');
reset role;

rollback;
\o
\echo admin announcements checks passed
