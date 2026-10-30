-- Rollback for 20261030170000_profile_avatar.sql. Uploaded avatar files stay
-- in the bucket; remove them in the dashboard if they are not wanted.
drop trigger if exists alumni_profiles_clear_avatar on alumni_profiles;
drop function if exists alumni_profiles_clear_avatar_on_delete();
drop function if exists profile_set_avatar(uuid, text);

-- account_files goes back to the version in 20261013090000_business_photo.sql.
create or replace function account_files(p_profile uuid)
returns table (bucket text, path text)
language sql
stable
security definer
set search_path = public
as $$
  select distinct 'marketplace'::text,
         substring(l.image_url from '/object/public/marketplace/([^?#]+)')
  from marketplace_listings l
  where (l.seller_id = p_profile
         or l.business_id in (select b.id from businesses b where b.owner_id = p_profile))
    and substring(l.image_url from '/object/public/marketplace/([^?#]+)') is not null
  union
  select 'cvs'::text, a.cv_path
  from job_applications a
  where a.applicant_id = p_profile and a.cv_path is not null and a.cv_path <> ''
  union
  select 'business-photos'::text,
         substring(b.photo_url from '/object/public/business-photos/([^?#]+)')
  from businesses b
  where b.owner_id = p_profile
    and substring(b.photo_url from '/object/public/business-photos/([^?#]+)') is not null;
$$;

drop policy if exists "avatars_public_read" on storage.objects;
drop policy if exists "avatars_public_upload" on storage.objects;
delete from storage.buckets where id = 'avatars';

alter table alumni_profiles drop constraint if exists alumni_profiles_avatar_url_check;
alter table alumni_profiles drop column if exists avatar_url;
