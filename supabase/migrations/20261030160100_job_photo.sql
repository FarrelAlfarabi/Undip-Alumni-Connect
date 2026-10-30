-- ============================================================================
-- Stage 6: an optional photo on a job post (30 Oct 2026).
--
--   * job_posts.image_url   public link to a file in the new `job-photos`
--                           bucket (images only, max 2 MB, same as
--                           `business-photos`). Optional: a job without one
--                           keeps the initials square.
--
-- Upload is open to the app's anon key, like business-photos and marketplace
-- (the app has no Supabase Auth session); size, type and extension are limited.
-- Jobs are written straight to the table by the app (no function), so only the
-- column, its link check and the bucket are needed.
--
-- Deleting an account: the bucket files are not removed with the account, same
-- as before for any photo bucket added after account_files(). Farrel can clear
-- them in the dashboard (Storage > job-photos > folder named after the
-- poster id). Say so in the report; no change to account_files() here.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_job_photo.sql
-- ============================================================================

alter table job_posts add column if not exists image_url text;

alter table job_posts drop constraint if exists job_posts_image_url_check;
alter table job_posts add constraint job_posts_image_url_check
  check (
    image_url is null
    or (char_length(image_url) <= 500
        and image_url ~ '^https://[^/?#]+/storage/v1/object/public/job-photos/[^?#]+$')
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'job-photos', 'job-photos', true, 2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- No read policy: a public bucket serves files by link, and a select policy
-- would also let anyone list every file path (folder names are poster ids).
drop policy if exists "job_photos_public_read" on storage.objects;

drop policy if exists "job_photos_public_upload" on storage.objects;
create policy "job_photos_public_upload" on storage.objects
  for insert with check (
    bucket_id = 'job-photos'
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );
