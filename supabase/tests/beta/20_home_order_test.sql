-- Home order: only an admin can set or list it; members cannot write
-- home_rank on their own product or job; the order is saved atomically.
-- App calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

-- Three jobs (one hidden) and the seeded approved listings.
insert into job_posts (posted_by, title, company, description) values
  ((select v from t_ids where k = 'siti'), 'HO Job A', 'PT', 'd'),
  ((select v from t_ids where k = 'siti'), 'HO Job B', 'PT', 'd'),
  ((select v from t_ids where k = 'siti'), 'HO Job C', 'PT', 'd');
update job_posts set hidden_at = now() where title = 'HO Job C';
create temp table t_jobs as
  select title, id from job_posts where title like 'HO Job %';
grant select on t_jobs to anon;
create temp table t_lst as
  select id, row_number() over (order by created_at, id) as n
  from marketplace_listings where status = 'approved' limit 3;
grant select on t_lst to anon;

-- The column exists, is null by default, and has a range check.
select jt.assert((select count(*) from job_posts where home_rank is not null) = 0, 'nothing pinned by default');
select jt.expect_error($q$update job_posts set home_rank = 0 where title = 'HO Job A'$q$, 'home_rank|check');
select jt.expect_error($q$update job_posts set home_rank = 100 where title = 'HO Job A'$q$, 'home_rank|check');
select jt.expect_error($q$update marketplace_listings set home_rank = 0 where id = (select id from t_lst where n = 1)$q$, 'home_rank|check');

set role anon;
-- Not an admin, unknown id, null: refused.
select jt.expect_error(format($q$select admin_set_home_order(%L, 'job', array[]::uuid[])$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error($q$select admin_set_home_order(gen_random_uuid(), 'job', array[]::uuid[])$q$, 'not_admin');
select jt.expect_error($q$select admin_set_home_order(null, 'job', array[]::uuid[])$q$, 'not_admin');
select jt.expect_error(format($q$select * from admin_home_order_list(%L, 'job')$q$, (select v from t_ids where k = 'siti')), 'not_admin');
-- Admin: bad kind, bad ids, duplicates, too many.
select jt.expect_error(format($q$select admin_set_home_order(%L, 'banner', array[]::uuid[])$q$, (select v from t_ids where k = 'clara')), 'invalid_kind');
select jt.expect_error(format($q$select admin_set_home_order(%L, null, array[]::uuid[])$q$, (select v from t_ids where k = 'clara')), 'invalid_kind');
select jt.expect_error(format($q$select admin_set_home_order(%L, 'job', array[gen_random_uuid()])$q$, (select v from t_ids where k = 'clara')), 'not_found');
select jt.expect_error(format($q$select admin_set_home_order(%L, 'job', array[%L, %L]::uuid[])$q$, (select v from t_ids where k = 'clara'), (select id from t_jobs where title = 'HO Job A'), (select id from t_jobs where title = 'HO Job A')), 'invalid_input');
select jt.expect_error(format($q$select admin_set_home_order(%L, 'job', array(select gen_random_uuid() from generate_series(1, 100)))$q$, (select v from t_ids where k = 'clara')), 'invalid_input');
reset role;
select jt.assert((select count(*) from job_posts where home_rank is not null) = 0, 'refused calls pinned nothing');

-- Admin sets an order, hidden job included (any status can be pinned).
set role anon;
select admin_set_home_order((select v from t_ids where k = 'clara'), 'job',
  array[(select id from t_jobs where title = 'HO Job C'), (select id from t_jobs where title = 'HO Job A')]);
reset role;
select jt.assert((select home_rank from job_posts where title = 'HO Job C') = 1, 'first id is rank 1');
select jt.assert((select home_rank from job_posts where title = 'HO Job A') = 2, 'second id is rank 2');
select jt.assert((select home_rank from job_posts where title = 'HO Job B') is null, 'unlisted job is not pinned');

-- A new list clears every item that is missing from it.
set role anon;
select admin_set_home_order((select v from t_ids where k = 'clara'), 'job',
  array[(select id from t_jobs where title = 'HO Job B')]);
reset role;
select jt.assert((select home_rank from job_posts where title = 'HO Job B') = 1, 'B is now rank 1');
select jt.assert((select home_rank from job_posts where title = 'HO Job A') is null, 'A cleared');
select jt.assert((select home_rank from job_posts where title = 'HO Job C') is null, 'C cleared');

-- Setting jobs does not touch listings, and an empty list clears the kind.
set role anon;
select admin_set_home_order((select v from t_ids where k = 'clara'), 'listing',
  array[(select id from t_lst where n = 2), (select id from t_lst where n = 1)]);
reset role;
select jt.assert((select home_rank from marketplace_listings where id = (select id from t_lst where n = 2)) = 1, 'listing rank 1');
select jt.assert((select home_rank from marketplace_listings where id = (select id from t_lst where n = 1)) = 2, 'listing rank 2');
select jt.assert((select home_rank from job_posts where title = 'HO Job B') = 1, 'jobs untouched by a listing save');

-- A failing call changes nothing (atomic): the bad id is last.
set role anon;
select jt.expect_error(format($q$select admin_set_home_order(%L, 'listing', array[%L, gen_random_uuid()])$q$, (select v from t_ids where k = 'clara'), (select id from t_lst where n = 3)), 'not_found');
reset role;
select jt.assert((select home_rank from marketplace_listings where id = (select id from t_lst where n = 3)) is null, 'failed save pinned nothing');
select jt.assert((select home_rank from marketplace_listings where id = (select id from t_lst where n = 2)) = 1, 'failed save kept the old order');

-- The admin list shows pinned items (any status) and candidates, with rank.
set role anon;
select admin_set_home_order((select v from t_ids where k = 'clara'), 'job',
  array[(select id from t_jobs where title = 'HO Job B'), (select id from t_jobs where title = 'HO Job C')]);
select jt.assert((select count(*) from admin_home_order_list((select v from t_ids where k = 'clara'), 'job') where title = 'HO Job C' and status = 'hidden') = 1, 'hidden job listed with status hidden');
select jt.assert((select home_rank from admin_home_order_list((select v from t_ids where k = 'clara'), 'job') where title = 'HO Job B') = 1, 'list carries rank');
select jt.assert((select count(*) from admin_home_order_list((select v from t_ids where k = 'clara'), 'listing') where status = 'approved') >= 3, 'approved listings listed');
reset role;

-- Members cannot write home_rank: not on their own job, not on an insert.
update job_posts set home_rank = null where title like 'HO Job %';
set role anon;
update job_posts set home_rank = 5 where title = 'HO Job A';
select jt.expect_error($q$update marketplace_listings set home_rank = 5$q$, 'permission denied');
reset role;
select jt.assert((select count(*) from job_posts where home_rank is not null) = 0, 'member update changed no job rank');
select jt.assert((select count(*) from marketplace_listings where home_rank = 5) = 0, 'member update changed no listing rank');
set role anon;
select jt.expect_error(format($q$insert into job_posts (posted_by, title, company, description, home_rank) values (%L, 'HO sneaky', 'PT', 'd', 1)$q$, (select v from t_ids where k = 'siti')), 'home_rank|row-level security|permission denied');
reset role;

-- Not callable through "public".
select jt.assert(not has_function_privilege('public', 'admin_set_home_order(uuid,text,uuid[])', 'execute'), 'public cannot set');
select jt.assert(has_function_privilege('anon', 'admin_set_home_order(uuid,text,uuid[])', 'execute'), 'anon can call');
select jt.assert(not has_function_privilege('public', 'admin_home_order_list(uuid,text)', 'execute'), 'public cannot list');

rollback;
\o
\echo home order checks passed
