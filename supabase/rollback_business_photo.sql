-- Rollback for 20261013090000_business_photo.sql. Uploaded photo files stay
-- in the bucket; remove them in the dashboard if they are not wanted.
drop function if exists business_set_photo(uuid, uuid, text);
drop function if exists business_photo_urls(uuid);
drop function if exists admin_business_photo_urls(uuid);

-- account_files goes back to the version in
-- 20261003170000_account_deletion_and_consent.sql (re-run that definition).

drop policy if exists "business_photos_public_read" on storage.objects;
drop policy if exists "business_photos_public_upload" on storage.objects;
delete from storage.buckets where id = 'business-photos';

alter table businesses drop constraint if exists businesses_photo_url_check;
alter table businesses drop column if exists photo_url;
