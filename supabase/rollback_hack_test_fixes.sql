-- Undo 20261113100000_hack_test_fixes.sql. Safe to run twice.
-- (The live-only job_applications_update policy and the update revokes on
-- job_applications are not restored on purpose.)
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name), ', ') into cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'alumni_profiles' and column_name <> 'nim';
  execute 'grant select (' || cols || ') on public.alumni_profiles to anon';
end $$;
drop policy if exists "job_applications_insert" on job_applications;
create policy "job_applications_insert" on job_applications for insert with check (true);
update storage.buckets set public = true where id = 'cvs';
drop policy if exists "cvs_poster_read" on storage.objects;
drop policy if exists "cvs_public_read" on storage.objects;
create policy "cvs_public_read" on storage.objects for select using (bucket_id = 'cvs');
do $$
declare b record;
begin
  for b in
    select * from (values
      ('avatars','jpg,jpeg,png,webp'), ('business-photos','jpg,jpeg,png,webp'),
      ('cvs','pdf,doc,docx'), ('job-photos','jpg,jpeg,png,webp'),
      ('marketplace','jpg,jpeg,png,webp'), ('sponsor-images','jpg,jpeg,png,webp')
    ) v(bucket, exts)
  loop
    execute format('drop policy if exists %I on storage.objects', replace(b.bucket, '-', '_') || '_public_upload');
    execute format(
      'create policy %I on storage.objects for insert with check (bucket_id = %L and lower(storage.extension(name)) = any (string_to_array(%L, '','')))',
      replace(b.bucket, '-', '_') || '_public_upload', b.bucket, b.exts);
  end loop;
end $$;
-- The 5 MB file size limit set where there was none is left in place.
create or replace function claim_alumni_profile()
returns alumni_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_row alumni_profiles%rowtype;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  select email into v_email from auth.users where id = v_uid;
  if v_email is null then raise exception 'No authenticated email found for this session'; end if;
  select * into v_row from alumni_profiles
   where lower(email) = lower(btrim(v_email)) and deleted_at is null
     and (user_id is null or user_id = v_uid)
   order by (user_id = v_uid) desc limit 1;
  if not found then raise exception 'No matching alumni record for this email'; end if;
  if v_row.suspended_at is not null then raise exception 'account_suspended'; end if;
  if v_row.user_id is null then
    update alumni_profiles set user_id = v_uid,
      verification_status = case when verification_status = 'unverified' then 'verified' else verification_status end
     where id = v_row.id returning * into v_row;
  end if;
  return v_row;
end;
$$;
