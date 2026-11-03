-- ============================================================================
-- Private CV bucket (web closed beta prep).
--
-- A CV holds a phone number, an address and a work history. Until now the
-- `cvs` bucket was public: anyone who had a file URL could open it, and
-- anyone with the public app key could upload to it.
--
-- After this migration:
--   * `cvs` is private. The app opens a CV with a short lived signed link.
--   * Reading a CV is allowed to: the applicant (own folder), and the person
--     who posted the job the CV was sent to. Nobody else.
--   * Uploading is allowed only into the signed in person's own folder
--     (first folder = auth user id) and only pdf, doc, docx (5 MB cap is the
--     bucket setting from 20260930100000_security_hardening.sql).
--   * A signed in person can delete files in their own folder.
--   * While require_login is off (the old build, before the cutover) uploads
--     and reads behave as before, so nothing breaks before the cutover.
--     After `supabase/cutover_real_login.sql` the strict rules apply.
--
-- Files already in the bucket keep working: old paths start with the job id,
-- and the job poster can read them through the application row.
--
-- Admin: the Supabase dashboard (service role) is not affected by these rules.
-- Idempotent. Rollback: supabase/rollback_private_cvs.sql
-- ============================================================================

update storage.buckets set public = false where id = 'cvs';

create or replace function cv_can_read(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    not login_required()
    or (
      auth.uid() is not null
      and (
        split_part(p_name, '/', 1) = auth.uid()::text
        or exists (
          select 1
            from job_applications ja
            join job_posts jp on jp.id = ja.job_post_id
            join alumni_profiles p on p.id = jp.posted_by
           where ja.cv_path = p_name
             and p.user_id = auth.uid()
        )
      )
    );
$$;

revoke execute on function cv_can_read(text) from public;
grant execute on function cv_can_read(text) to anon, authenticated;

drop policy if exists "cvs_public_upload" on storage.objects;
drop policy if exists "cvs_upload" on storage.objects;
create policy "cvs_upload" on storage.objects
  for insert with check (
    bucket_id = 'cvs'
    and lower(storage.extension(name)) in ('pdf', 'doc', 'docx')
    and (
      not login_required()
      or (auth.uid() is not null and split_part(name, '/', 1) = auth.uid()::text)
    )
  );

drop policy if exists "cvs_read" on storage.objects;
create policy "cvs_read" on storage.objects
  for select using (bucket_id = 'cvs' and cv_can_read(name));

drop policy if exists "cvs_delete_own" on storage.objects;
create policy "cvs_delete_own" on storage.objects
  for delete using (
    bucket_id = 'cvs'
    and auth.uid() is not null
    and split_part(name, '/', 1) = auth.uid()::text
  );
