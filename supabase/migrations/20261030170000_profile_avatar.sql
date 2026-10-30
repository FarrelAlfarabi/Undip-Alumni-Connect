-- ============================================================================
-- Profile photo (Stage 7 of the redesign, 30 Oct 2026).
--
--   * alumni_profiles.avatar_url   public link to a file in the new `avatars`
--                                  bucket (images only, max 2 MB)
--   * profile_set_avatar()         sets or clears it; only the person's own
--                                  verified profile (assert_caller + id match)
--   * avatar_url is granted to anon and authenticated like the other
--     readable columns (see 20261018120000_hide_nim.sql)
--   * account_files() lists the avatar, so deleting an account queues the
--     file for removal; a trigger clears avatar_url when deleted_at is set
--
-- The bucket is public-read like `business-photos`: anyone holding the exact
-- link can open the file, but the link is only returned to verified members
-- who read profiles. File names carry the profile id and a timestamp.
--
-- Same limit as the other functions: until real sessions are required, the
-- profile id is not proven (assert_caller only checks when login is on).
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_profile_avatar.sql
-- ============================================================================

alter table alumni_profiles add column if not exists avatar_url text;

alter table alumni_profiles drop constraint if exists alumni_profiles_avatar_url_check;
alter table alumni_profiles add constraint alumni_profiles_avatar_url_check
  check (
    avatar_url is null
    or (char_length(avatar_url) <= 500
        and avatar_url ~ '^https://[^/]+/storage/v1/object/public/avatars/[^?#]+')
  );

grant select (avatar_url) on alumni_profiles to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Storage bucket: public read, open upload for images only (same model and
-- limit as `business-photos`: no Supabase Auth session on upload).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars', 'avatars', true, 2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_public_upload" on storage.objects;
create policy "avatars_public_upload" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

-- ---------------------------------------------------------------------------
-- Set or clear my own photo. An empty value clears it. The link must point to
-- a file under my own profile id in the avatars bucket (the app uploads it
-- there), so nobody can link another person's file or an outside address.
-- ---------------------------------------------------------------------------
create or replace function profile_set_avatar(p_profile uuid, p_url text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text := nullif(btrim(coalesce(p_url, '')), '');
  v_status text;
begin
  perform assert_caller(p_profile);
  select verification_status into v_status
    from alumni_profiles
   where id = p_profile and deleted_at is null
   for update;
  if not found then raise exception 'not_found'; end if;
  if v_status <> 'verified' then raise exception 'not_verified'; end if;
  if v_url is not null
     and (char_length(v_url) > 500
          or v_url !~ ('^https://[^/]+/storage/v1/object/public/avatars/'
                       || p_profile::text || '/[^?#]+$')) then
    raise exception 'invalid_input';
  end if;

  update alumni_profiles
     set avatar_url = v_url, updated_at = now()
   where id = p_profile;
  return v_url;
end;
$$;

-- ---------------------------------------------------------------------------
-- Deleting an account: the photo link is cleared and the file is queued for
-- removal (account_delete copies account_files() into storage_cleanup_queue).
-- ---------------------------------------------------------------------------
create or replace function alumni_profiles_clear_avatar_on_delete()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    new.avatar_url := null;
  end if;
  return new;
end;
$$;

drop trigger if exists alumni_profiles_clear_avatar on alumni_profiles;
create trigger alumni_profiles_clear_avatar
  before update on alumni_profiles
  for each row execute function alumni_profiles_clear_avatar_on_delete();

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
    and substring(b.photo_url from '/object/public/business-photos/([^?#]+)') is not null
  union
  select 'avatars'::text,
         substring(p.avatar_url from '/object/public/avatars/([^?#]+)')
  from alumni_profiles p
  where p.id = p_profile
    and substring(p.avatar_url from '/object/public/avatars/([^?#]+)') is not null;
$$;

revoke execute on function profile_set_avatar(uuid, text) from public;
revoke execute on function account_files(uuid) from public;
revoke execute on function alumni_profiles_clear_avatar_on_delete() from public, anon, authenticated;
grant execute on function profile_set_avatar(uuid, text) to anon, authenticated;
grant execute on function account_files(uuid) to anon, authenticated;
