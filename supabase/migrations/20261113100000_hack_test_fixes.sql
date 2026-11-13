-- Security hardening after the 13 Nov 2026 hack test (real login ON).
-- Closes what the login switch alone leaves open:
--   1. Strangers (anon) could read every alumni email and auth id.
--   2. Job application status could be changed by anyone (a policy that
--      exists only on the live database, not in earlier migrations), and
--      anyone could file an application as another person.
--   3. The cvs bucket was public and every bucket took uploads from anyone.
--   4. claim_alumni_profile did not check the sign in email is confirmed.
-- Apply TOGETHER with the real login cutover (the old email-only build reads
-- the alumni table as anon and stops working, as it does after the cutover).
-- Idempotent. Rollback: supabase/rollback_hack_test_fixes.sql

-- 1. alumni_profiles: signed in members only.
revoke select on alumni_profiles from anon;
-- Column grants survive a table level revoke: remove them one by one.
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name), ', ') into cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'alumni_profiles';
  execute 'revoke select (' || cols || ') on public.alumni_profiles from anon';
end $$;

-- 2. job_applications: no direct status edits; apply only as yourself.
drop policy if exists "job_applications_update" on job_applications;
revoke update on job_applications from anon, authenticated;
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name), ', ') into cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'job_applications';
  execute 'revoke update (' || cols || ') on public.job_applications from anon, authenticated';
end $$;
drop policy if exists "job_applications_insert" on job_applications;
create policy "job_applications_insert" on job_applications
  for insert
  with check (
    not login_required()
    or applicant_id = current_profile_id()
  );

-- 3. Storage.
-- 3a. cvs: private. The poster of the job reads CVs through a signed link;
-- the first folder of the path is the job id.
update storage.buckets set public = false where id = 'cvs';
drop policy if exists "cvs_public_read" on storage.objects;
drop policy if exists "cvs_poster_read" on storage.objects;
create policy "cvs_poster_read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'cvs'
    and exists (
      select 1 from job_posts j
       where j.id::text = split_part(name, '/', 1)
         and j.posted_by = current_profile_id()
    )
  );

-- 3b. Uploads need a signed in caller once login is required. Each policy is
-- rebuilt from a fixed expression, so running this twice changes nothing.
do $$
declare
  b record;
  base text;
begin
  for b in
    select * from (values
      ('avatars',        'jpg,jpeg,png,webp'),
      ('business-photos','jpg,jpeg,png,webp'),
      ('cvs',            'pdf,doc,docx'),
      ('job-photos',     'jpg,jpeg,png,webp'),
      ('marketplace',    'jpg,jpeg,png,webp'),
      ('sponsor-images', 'jpg,jpeg,png,webp')
    ) v(bucket, exts)
  loop
    base := format('bucket_id = %L and lower(storage.extension(name)) = any (string_to_array(%L, '',''))', b.bucket, b.exts);
    if b.bucket = 'cvs' then
      -- A CV goes into the folder of an open job (the first folder is the job id).
      base := base || ' and exists (select 1 from public.job_posts j where j.id::text = split_part(name, ''/'', 1))';
    end if;
    execute format('drop policy if exists %I on storage.objects', replace(b.bucket, '-', '_') || '_public_upload');
    execute format(
      'create policy %I on storage.objects for insert with check (%s and (not public.login_required() or auth.uid() is not null))',
      replace(b.bucket, '-', '_') || '_public_upload', base);
  end loop;
end $$;

-- 3c. A size limit where there is none (5 MB).
update storage.buckets set file_size_limit = 5242880
 where id in ('avatars', 'business-photos', 'cvs', 'job-photos', 'marketplace', 'sponsor-images')
   and file_size_limit is null;

-- 4. Claiming a profile needs a confirmed email on the auth user.
create or replace function claim_alumni_profile()
returns alumni_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_confirmed timestamptz;
  v_row alumni_profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select email, email_confirmed_at into v_email, v_confirmed
    from auth.users where id = v_uid;
  if v_email is null then
    raise exception 'No authenticated email found for this session';
  end if;
  if v_confirmed is null then
    raise exception 'email_not_confirmed';
  end if;

  select * into v_row
    from alumni_profiles
   where lower(email) = lower(btrim(v_email))
     and deleted_at is null
     and (user_id is null or user_id = v_uid)
   order by (user_id = v_uid) desc
   limit 1;

  if not found then
    raise exception 'No matching alumni record for this email';
  end if;

  if v_row.suspended_at is not null then
    raise exception 'account_suspended';
  end if;

  if v_row.user_id is null then
    update alumni_profiles
       set user_id = v_uid,
           verification_status = case
             when verification_status = 'unverified' then 'verified'
             else verification_status end
     where id = v_row.id
    returning * into v_row;
  end if;

  return v_row;
end;
$$;
revoke all on function claim_alumni_profile() from public, anon;
grant execute on function claim_alumni_profile() to authenticated;
