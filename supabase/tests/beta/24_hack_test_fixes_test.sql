-- Security hardening (13 Nov 2026): with require_login on, a stranger (anon)
-- cannot read the alumni table, nobody can change job application status,
-- applying is only possible as yourself, only signed in people upload files,
-- the cvs bucket is private, and claiming a profile needs a confirmed email.
\set ON_ERROR_STOP on
\o /dev/null
begin;

-- Stand-in for Supabase auth: uid from the request claims, confirmed flag.
alter table auth.users add column if not exists email text;
alter table auth.users add column if not exists email_confirmed_at timestamptz default now();
create or replace function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

update app_settings set value = 'on' where key = 'require_login';

insert into auth.users (id, email, email_confirmed_at) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'ahmad.ramadhan@example.com', now());
update alumni_profiles set user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'
  where email = 'ahmad.ramadhan@example.com';
select id as a from alumni_profiles where email = 'ahmad.ramadhan@example.com' \gset
select id as b from alumni_profiles where email = 'siti.azizah@example.com' \gset

-- Fixture job (inserted as the table owner).
insert into job_posts (posted_by, title, company, description)
  values (:'b', 't', 'c', 'd') returning id as jp \gset

-- 1. Anon cannot read alumni_profiles at all.
set role anon;
select jt.expect_error($q$select email from alumni_profiles$q$, 'permission denied');
reset role;

-- 2. Nobody can change application status straight on the table.
insert into job_applications (job_post_id, applicant_id, full_name, email)
  values (:'jp', :'b', 'V', 'v@x.com');
set role anon;
select jt.expect_error($q$update job_applications set full_name = 'HACKED'$q$, 'permission denied|row-level');
reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);
set role authenticated;
select jt.expect_error($q$update job_applications set full_name = 'HACKED'$q$, 'permission denied|row-level');

-- 3. Applying as someone else is refused, as yourself works.
select jt.expect_error(format($q$insert into job_applications (job_post_id, applicant_id, full_name, email) values (%L, %L, 'x', 'x@x.com')$q$, :'jp', :'b'), 'row-level security');
insert into job_applications (job_post_id, applicant_id, full_name, email) values (:'jp', :'a', 'Me', 'me@x.com');
reset role;
-- ...and a stranger (no token) cannot apply at all.
select set_config('request.jwt.claim.sub', '', true);
set role anon;
select jt.expect_error(format($q$insert into job_applications (job_post_id, applicant_id, full_name, email) values (%L, %L, 'x', 'x@x.com')$q$, :'jp', :'a'), 'row-level security|permission denied');
reset role;

-- 4. Storage: cvs private, no public read policy, uploads need a signed in caller.
select jt.assert((select not public from storage.buckets where id = 'cvs'), 'cvs bucket is private');
select jt.assert(not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'cvs_public_read'), 'no cvs public read');
set role anon;
select jt.expect_error($q$insert into storage.objects (bucket_id, name) values ('avatars', 'x/y.png')$q$, 'row-level security|permission denied');
reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);
set role authenticated;
insert into storage.objects (bucket_id, name) values ('avatars', 'x/y.png');
reset role;

-- 5. Claiming a profile needs a confirmed email.
update alumni_profiles set user_id = null where email = 'ahmad.ramadhan@example.com';
update auth.users set email_confirmed_at = null where id = 'aaaaaaaa-0000-0000-0000-00000000000a';
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);
set role authenticated;
select jt.expect_error($q$select * from claim_alumni_profile()$q$, 'email_not_confirmed');
reset role;
update auth.users set email_confirmed_at = now() where id = 'aaaaaaaa-0000-0000-0000-00000000000a';
set role authenticated;
select jt.assert((select count(*) from claim_alumni_profile()) = 1, 'confirmed email can claim');
reset role;

-- 6. Members still read the profile columns the app needs, never NIM.
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);
set role authenticated;
select jt.assert((select count(*) from alumni_profiles where name is not null) > 0, 'member reads profiles');
select jt.expect_error($q$select nim from alumni_profiles$q$, 'permission denied');
reset role;

-- 7. CVs: only the poster reads, and only into an open job's folder.
insert into storage.objects (bucket_id, name) values ('cvs', :'jp' || '/1_cv.pdf');
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);
set role authenticated;
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs') = 0, 'a non-poster cannot read the CV');
select jt.expect_error($q$insert into storage.objects (bucket_id, name) values ('cvs', 'not-a-job/1_cv.pdf')$q$, 'row-level security');
reset role;
update alumni_profiles set user_id = null where id = :'a';
update alumni_profiles set user_id = 'aaaaaaaa-0000-0000-0000-00000000000a' where id = :'b';
set role authenticated;
select jt.assert((select count(*) from storage.objects where bucket_id = 'cvs') = 1, 'the poster reads the CV');
reset role;

-- 8. Applying as yourself still works while login is not required.
update app_settings set value = 'off' where key = 'require_login';
select set_config('request.jwt.claim.sub', '', true);
set role anon;
insert into job_applications (job_post_id, applicant_id, full_name, email) values (:'jp', :'a', 'Off', 'off@x.com');
reset role;

rollback;
\o
