-- Admin permanent delete of jobs and listings: non-admins refused, login
-- required, reason required, Riwayat row, applications go with the job.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set verification_status = 'verified', user_id = null, suspended_at = null
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com',
                  'dewi.sari@example.com', 'bagas.prasetyo@example.com', 'fajar.nugroho@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'dewi', jt.pid('dewi.sari@example.com');
insert into t_ids select 'bagas', jt.pid('bagas.prasetyo@example.com');
insert into t_ids select 'fajar', jt.pid('fajar.nugroho@example.com');
delete from app_admins;
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

insert into job_posts (posted_by, title, company, description) values ((select v from t_ids where k = 'dewi'), 'Lowongan uji hapus', 'c', 'd');
create temp table t_items (k text primary key, v uuid);
grant all on t_items to anon, authenticated;
insert into t_items select 'job', id from job_posts where title = 'Lowongan uji hapus';
insert into t_items select 'listing', id from marketplace_listings limit 1;
select jt.assert((select count(*) from t_items) = 2, 'a job and a listing to delete');
insert into job_applications (job_post_id, applicant_id, full_name, email) values ((select v from t_items where k = 'job'), (select v from t_ids where k = 'siti'), 'Siti', 's@example.com');
insert into content_reports (reporter_id, target_type, target_id, reason) values ((select v from t_ids where k = 'siti'), 'job', (select v from t_items where k = 'job'), 'spam_or_scam');
select jt.assert(not has_function_privilege('public', 'admin_job_delete(uuid, uuid, text)', 'execute'), 'public cannot delete jobs');
select jt.assert(not has_function_privilege('public', 'admin_listing_delete(uuid, uuid, text)', 'execute'), 'public cannot delete listings');

set role anon;
select jt.expect_error(format($q$select admin_job_delete(%L, %L, 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_items where k = 'job')), 'login_required');
select jt.expect_error(format($q$select admin_listing_delete(%L, %L, 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_items where k = 'listing')), 'login_required');
reset role;

alter table auth.users add column if not exists email text;
insert into t_ids select 'u' || k, gen_random_uuid() from t_ids;
insert into auth.users (id, email) select u.v, p.email from t_ids u join t_ids k on 'u' || k.k = u.k join alumni_profiles p on p.id = k.v;
update alumni_profiles p set user_id = u.v from t_ids k join t_ids u on u.k = 'u' || k.k where p.id = k.v;
update app_settings set value = 'on' where key = 'require_login';
create or replace function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('test.uid', (select v::text from t_ids where k = 'u' || p), false) $$;

set role anon;
select pg_temp.as_user('dewi');
select jt.expect_error(format($q$select admin_job_delete(%L, %L, 'spam')$q$, (select v from t_ids where k = 'dewi'), (select v from t_items where k = 'job')), 'not_admin');
select jt.expect_error(format($q$select admin_listing_delete(%L, %L, 'spam')$q$, (select v from t_ids where k = 'dewi'), (select v from t_items where k = 'listing')), 'not_admin');
select jt.expect_error(format($q$select admin_job_delete(%L, %L, 'spam')$q$, (select v from t_ids where k = 'clara'), (select v from t_items where k = 'job')), 'not_admin');
select pg_temp.as_user('clara');
select jt.expect_error(format($q$select admin_job_delete(%L, %L, '')$q$, (select v from t_ids where k = 'clara'), (select v from t_items where k = 'job')), 'reason_required');
select jt.expect_error(format($q$select admin_listing_delete(%L, gen_random_uuid(), 'x')$q$, (select v from t_ids where k = 'clara')), 'not_found');
select jt.expect_error(format($q$select admin_job_delete(%L, gen_random_uuid(), 'x')$q$, (select v from t_ids where k = 'clara')), 'not_found');
select admin_job_delete((select v from t_ids where k = 'clara'), (select v from t_items where k = 'job'), 'Spam');
select admin_listing_delete((select v from t_ids where k = 'clara'), (select v from t_items where k = 'listing'), 'Penipuan');
reset role;
select jt.assert(not exists (select 1 from job_posts where id = (select v from t_items where k = 'job')), 'job deleted');
select jt.assert(not exists (select 1 from job_applications where job_post_id = (select v from t_items where k = 'job')), 'applications deleted');
select jt.assert(not exists (select 1 from marketplace_listings where id = (select v from t_items where k = 'listing')), 'listing deleted');
select jt.assert(not exists (select 1 from content_reports where target_type = 'job' and target_id = (select v from t_items where k = 'job')), 'job reports deleted');
select jt.assert((select count(*) from admin_actions where action in ('job_delete', 'listing_delete')) = 2, 'deletes logged');
select jt.assert((select detail = 'Lowongan uji hapus: Spam' and target_id = (select v from t_items where k = 'job')::text
                    and admin_id = (select v from t_ids where k = 'clara')
                    from admin_actions where action = 'job_delete'), 'job delete log row has title, reason, target');

rollback;
\o
\echo admin delete posts checks passed
