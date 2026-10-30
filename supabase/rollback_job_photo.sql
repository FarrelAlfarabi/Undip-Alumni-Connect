-- Rollback for 20261030160100_job_photo.sql. Uploaded files stay in the
-- bucket; remove them in the dashboard if they are not wanted.
drop policy if exists "job_photos_public_read" on storage.objects;
drop policy if exists "job_photos_public_upload" on storage.objects;
delete from storage.buckets where id = 'job-photos';

alter table job_posts drop constraint if exists job_posts_image_url_check;
alter table job_posts drop column if exists image_url;
