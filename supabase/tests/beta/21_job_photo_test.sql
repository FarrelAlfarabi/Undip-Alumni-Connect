-- Job photo: optional, only a link into the job-photos bucket is accepted.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com');

select jt.assert(exists (select 1 from storage.buckets where id = 'job-photos' and public and file_size_limit = 2097152), 'bucket exists, public, 2 MB');
select jt.assert(exists (select 1 from information_schema.columns where table_name = 'job_posts' and column_name = 'image_url'), 'image_url column exists');

-- A job without a photo is still fine.
insert into job_posts (posted_by, title, company, description, contact_info)
  values (jt.pid('ahmad.ramadhan@example.com'), 'Akuntan', 'PT A', 'd', 'a@example.com');
select jt.assert((select count(*) from job_posts where title = 'Akuntan' and image_url is null) = 1, 'job without photo');

-- A job with a link into the bucket is fine.
insert into job_posts (posted_by, title, company, description, contact_info, image_url)
  values (jt.pid('ahmad.ramadhan@example.com'), 'Auditor', 'PT B', 'd', 'b@example.com',
    'https://x.supabase.co/storage/v1/object/public/job-photos/AHMADID/1_kantor.png');
select jt.assert((select count(*) from job_posts where title = 'Auditor' and image_url like '%/job-photos/AHMADID/%') = 1, 'job with photo');

-- Any other link is refused.
select jt.expect_error(format($q$insert into job_posts (posted_by, title, company, description, contact_info, image_url) values (%L, 'X', 'Y', 'd', 'c@example.com', 'https://evil.example/pic.png')$q$, jt.pid('ahmad.ramadhan@example.com')), 'job_posts_image_url_check');
select jt.expect_error(format($q$insert into job_posts (posted_by, title, company, description, contact_info, image_url) values (%L, 'X', 'Y', 'd', 'c@example.com', 'https://x.supabase.co/storage/v1/object/public/business-photos/a.png')$q$, jt.pid('ahmad.ramadhan@example.com')), 'job_posts_image_url_check');

rollback;
\o
select 'job photo ok';
