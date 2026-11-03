-- Rolls back 20261103150000_private_cvs.sql: the bucket is public again and
-- anyone can upload a pdf, doc or docx, as before. Idempotent.
drop policy if exists "cvs_read" on storage.objects;
drop policy if exists "cvs_delete_own" on storage.objects;
drop policy if exists "cvs_upload" on storage.objects;
drop function if exists cv_can_read(text);

update storage.buckets set public = true where id = 'cvs';

drop policy if exists "cvs_public_upload" on storage.objects;
create policy "cvs_public_upload" on storage.objects
  for insert with check (
    bucket_id = 'cvs'
    and lower(storage.extension(name)) in ('pdf', 'doc', 'docx')
  );
