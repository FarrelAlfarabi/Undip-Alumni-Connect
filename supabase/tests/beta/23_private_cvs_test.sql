-- Private CV bucket: signed links only, uploads and reads tied to the signed in
-- person. While require_login is off nothing changes for old builds.
-- Runs in a transaction that is rolled back.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ua', gen_random_uuid();   -- ahmad (applicant)
insert into t_ids select 'us', gen_random_uuid();   -- siti (job poster)
insert into t_ids select 'ub', gen_random_uuid();   -- bagas (stranger)
insert into auth.users (id, email) select v, k from t_ids;
update alumni_profiles set user_id = (select v from t_ids where k = 'ua') where email = 'ahmad.ramadhan@example.com';
update alumni_profiles set user_id = (select v from t_ids where k = 'us') where email = 'siti.azizah@example.com';
update alumni_profiles set user_id = (select v from t_ids where k = 'ub') where email = 'bagas.prasetyo@example.com';

with x as (insert into job_posts (posted_by, title, company, description)
  values (jt.pid('siti.azizah@example.com'), 'Analis', 'PT B', 'd') returning id)
insert into t_ids select 'job', id from x;
-- One application with a new style path (folder = the applicant's auth id),
-- one with an old style path (folder = the job id).
insert into job_applications (job_post_id, applicant_id, full_name, email, cv_path)
  values ((select v from t_ids where k = 'job'), jt.pid('ahmad.ramadhan@example.com'), 'Ahmad', 'a@example.com',
          (select v::text from t_ids where k = 'ua') || '/job_1_cv.pdf');
insert into job_applications (job_post_id, applicant_id, full_name, email, cv_path)
  values ((select v from t_ids where k = 'job'), jt.pid('bagas.prasetyo@example.com'), 'Bagas', 'b@example.com',
          (select v::text from t_ids where k = 'job') || '/old_cv.pdf');
insert into storage.objects (bucket_id, name) values
  ('cvs', (select v::text from t_ids where k = 'ua') || '/job_1_cv.pdf'),
  ('cvs', (select v::text from t_ids where k = 'job') || '/old_cv.pdf');

select jt.assert((select public = false from storage.buckets where id = 'cvs'), 'cvs bucket is private');
select jt.assert((select count(*) from storage.buckets where public and id = 'cvs') = 0, 'cvs is not public');

-- ---- switch OFF: old builds keep working (anonymous upload and read) -------
set role anon;
insert into storage.objects (bucket_id, name) values ('cvs', 'legacy/off.pdf');
select jt.expect_error($q$insert into storage.objects (bucket_id, name) values ('cvs', 'legacy/off.exe')$q$, 'row-level security');
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs' and name = 'legacy/off.pdf') = 1, 'off: legacy read still works');
reset role;

-- ---- switch ON -------------------------------------------------------------
update app_settings set value = 'on' where key = 'require_login';

-- Not signed in: nothing in, nothing out.
set role anon;
select jt.expect_error($q$insert into storage.objects (bucket_id, name) values ('cvs', 'x/anon.pdf')$q$, 'row-level security');
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs') = 0, 'on: anon sees no CV');
reset role;

-- Ahmad: uploads only into his own folder, only pdf/doc/docx, reads his own file.
set role authenticated;
select set_config('test.uid', (select v::text from t_ids where k = 'ua'), true);
insert into storage.objects (bucket_id, name) values ('cvs', (select v::text from t_ids where k = 'ua') || '/job_2_cv2.pdf');
select jt.expect_error(format($q$insert into storage.objects (bucket_id, name) values ('cvs', %L)$q$, (select v::text from t_ids where k = 'us') || '/fake.pdf'), 'row-level security');
select jt.expect_error(format($q$insert into storage.objects (bucket_id, name) values ('cvs', %L)$q$, (select v::text from t_ids where k = 'ua') || '/bad.exe'), 'row-level security');
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs' and name = (select v::text from t_ids where k = 'ua') || '/job_1_cv.pdf') = 1, 'applicant reads own CV');
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs' and name = (select v::text from t_ids where k = 'job') || '/old_cv.pdf') = 0, 'applicant cannot read someone else CV');
reset role;

-- Siti posted the job: reads both applicants CVs (new and old path style).
set role authenticated;
select set_config('test.uid', (select v::text from t_ids where k = 'us'), true);
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs' and name in (
  (select v::text from t_ids where k = 'ua') || '/job_1_cv.pdf',
  (select v::text from t_ids where k = 'job') || '/old_cv.pdf')) = 2, 'job poster reads the CVs of her applicants');
-- A file nobody applied with is not readable by her (ahmad's second upload has no application).
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs' and name = (select v::text from t_ids where k = 'ua') || '/job_2_cv2.pdf') = 0, 'poster cannot read a CV that is not tied to an application');
reset role;

-- Bagas applied to nothing of Ahmad's and posted nothing: he reads only his own folder (none).
set role authenticated;
select set_config('test.uid', (select v::text from t_ids where k = 'ub'), true);
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs' and name like (select v::text from t_ids where k = 'ua') || '/%') = 0, 'stranger reads no CV of Ahmad');
reset role;

-- Deleting: only inside the own folder.
set role authenticated;
select set_config('test.uid', (select v::text from t_ids where k = 'ub'), true);
delete from storage.objects where bucket_id = 'cvs' and name like (select v::text from t_ids where k = 'ua') || '/%';
reset role;
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs' and name like (select v::text from t_ids where k = 'ua') || '/%') = 2, 'stranger could not delete');
set role authenticated;
select set_config('test.uid', (select v::text from t_ids where k = 'ua'), true);
delete from storage.objects where bucket_id = 'cvs' and name = (select v::text from t_ids where k = 'ua') || '/job_2_cv2.pdf';
reset role;
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs' and name like (select v::text from t_ids where k = 'ua') || '/%') = 1, 'owner deleted own file');

rollback;
\o
\echo private cvs checks passed
