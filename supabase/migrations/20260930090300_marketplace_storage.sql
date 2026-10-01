-- ============================================================================
-- Marketplace demo: public image bucket for listing photos.
--
-- Same shape as the existing `cvs` bucket (public read, open upload, since
-- the app has no Supabase Auth session), plus limits the cvs bucket lacks:
-- images only, max 2 MB. Anyone holding the anon key can upload here; that
-- is the base auth model's limit, not something this bucket can fix.
--
-- Idempotent: safe to re-run.
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'marketplace', 'marketplace', true, 2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "marketplace_public_read" on storage.objects;
create policy "marketplace_public_read" on storage.objects
  for select using (bucket_id = 'marketplace');

drop policy if exists "marketplace_public_upload" on storage.objects;
create policy "marketplace_public_upload" on storage.objects
  for insert with check (
    bucket_id = 'marketplace'
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );
