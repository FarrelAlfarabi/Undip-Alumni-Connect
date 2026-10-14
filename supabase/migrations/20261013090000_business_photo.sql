-- ============================================================================
-- Business photo (13 Oct 2026).
--
-- A business can have one photo (a logo or a picture of the products). The
-- owner adds it while the business is pending or rejected, so an admin sees it
-- before approving; once approved it is locked, the same as the other fields.
--
--   * businesses.photo_url   public link to a file in the new `business-photos`
--                            bucket (images only, max 2 MB, like `marketplace`)
--   * business_set_photo()   sets or clears it (owner only, pending/rejected)
--   * business_photo_urls() / admin_business_photo_urls() give the photos for
--                            the directory and the admin list
--   * account_files() also lists the photo, so deleting an account removes it
--
-- business_my() returns the whole row, so it picks the column up by itself.
-- The other lists are not changed: older app builds keep working.
-- Same limit as every other function here: the owner id is not authenticated
-- (see 20261003100000_business_directory.sql).
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_business_photo.sql
-- ============================================================================

alter table businesses add column if not exists photo_url text;

alter table businesses drop constraint if exists businesses_photo_url_check;
alter table businesses add constraint businesses_photo_url_check
  check (
    photo_url is null
    or (char_length(photo_url) <= 500
        and photo_url ~ '/object/public/business-photos/[^?#]+')
  );

-- ---------------------------------------------------------------------------
-- Storage bucket: public read, open upload for images only (same model and
-- same limit as the `marketplace` bucket: no Supabase Auth session).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'business-photos', 'business-photos', true, 2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "business_photos_public_read" on storage.objects;
create policy "business_photos_public_read" on storage.objects
  for select using (bucket_id = 'business-photos');

drop policy if exists "business_photos_public_upload" on storage.objects;
create policy "business_photos_public_upload" on storage.objects
  for insert with check (
    bucket_id = 'business-photos'
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

-- ---------------------------------------------------------------------------
-- Set or clear the photo of one of my businesses.
-- ---------------------------------------------------------------------------
create or replace function business_set_photo(
  p_owner uuid,
  p_business uuid,
  p_photo_url text
)
returns businesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v businesses;
  v_url text := nullif(btrim(coalesce(p_photo_url, '')), '');
begin
  select * into v from businesses where id = p_business for update;
  if not found then raise exception 'not_found'; end if;
  if v.owner_id <> p_owner then raise exception 'not_owner'; end if;
  if v.status not in ('pending', 'rejected') then raise exception 'locked'; end if;
  if v_url is not null
     and (char_length(v_url) > 500
          or v_url !~ '/object/public/business-photos/[^?#]+') then
    raise exception 'invalid_input';
  end if;

  update businesses set photo_url = v_url where id = p_business
  returning * into v;
  return v;
end;
$$;

-- ---------------------------------------------------------------------------
-- Photos for the lists. business_directory() and admin_businesses_list() are
-- left exactly as they are (changing what a function returns would break
-- older app builds and re-running the earlier migrations). The app asks for
-- the photos with these two small functions and puts them on the rows.
-- ---------------------------------------------------------------------------
-- Photos of the businesses the directory shows (approved, not hidden), for
-- verified alumni only.
create or replace function business_photo_urls(p_viewer uuid)
returns table (business_id uuid, photo_url text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not business_is_verified(p_viewer) then raise exception 'not_verified'; end if;
  return query
    select b.id, b.photo_url
    from businesses b
    where b.status = 'approved' and b.hidden_at is null and b.photo_url is not null;
end;
$$;

-- Photos of every business that has one, for admins.
create or replace function admin_business_photo_urls(p_admin uuid)
returns table (business_id uuid, photo_url text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select b.id, b.photo_url from businesses b where b.photo_url is not null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Deleting an account also removes the business photos of that person.
-- Same as before, plus the new bucket.
-- ---------------------------------------------------------------------------
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

revoke execute on function business_set_photo(uuid, uuid, text) from public;
revoke execute on function business_photo_urls(uuid) from public;
revoke execute on function admin_business_photo_urls(uuid) from public;
revoke execute on function account_files(uuid) from public;
grant execute on function business_set_photo(uuid, uuid, text) to anon, authenticated;
grant execute on function business_photo_urls(uuid) to anon, authenticated;
grant execute on function admin_business_photo_urls(uuid) to anon, authenticated;
grant execute on function account_files(uuid) to anon, authenticated;
