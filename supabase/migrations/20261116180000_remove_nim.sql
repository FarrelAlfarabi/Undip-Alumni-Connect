-- ============================================================================
-- Remove NIM (16 Nov 2026). Farrel: "Erase NIM entirely from app and
-- database". He chose no backup: the values are gone after this runs.
--
--   * Login passwords that were set to the person's NIM (the old demo login,
--     provision_alumni_accounts) are cleared first. Login is the email code,
--     which needs no password, so nobody is locked out.
--   * provision_alumni_accounts() is dropped (it used NIM as the password).
--   * profile_nim() is dropped (the app no longer shows NIM).
--   * alumni_profiles_restrict_update() is the same as live, minus its nim
--     line. account_delete() too, unless account_delete_core() exists (it
--     already copes with a missing nim column).
--   * alumni_profiles.nim and its unique key go. Email stays the unique key
--     (alumni_profiles_email_key).
--
-- Idempotent. Rollback: supabase/rollback_remove_nim.sql (brings back an
-- EMPTY nim column and the old functions; the values cannot come back).
-- ============================================================================

-- 1. Passwords equal to the NIM. Only where auth.users has passwords (the
--    local test stub has none). Stops if pgcrypto is missing: once the column
--    is dropped these passwords could no longer be found.
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'alumni_profiles' and column_name = 'nim')
     and exists (select 1 from information_schema.columns
                  where table_schema = 'auth' and table_name = 'users' and column_name = 'encrypted_password')
  then
    if to_regprocedure('extensions.crypt(text,text)') is null then
      raise exception 'remove_nim: extensions.crypt is missing, cannot clear NIM passwords';
    end if;
    execute $q$
      update auth.users u
         set encrypted_password = '', updated_at = now()
        from public.alumni_profiles a
       where lower(a.email) = lower(u.email)
         and a.nim is not null and a.nim <> ''
         and coalesce(u.encrypted_password, '') <> ''
         and u.encrypted_password = extensions.crypt(a.nim, u.encrypted_password)
    $q$;
  end if;
end $$;

-- 2. Functions that read NIM.
drop function if exists provision_alumni_accounts();
drop function if exists profile_nim(uuid, uuid);

create or replace function alumni_profiles_restrict_update()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if new.id <> old.id
     or new.user_id is distinct from old.user_id
     or new.name <> old.name
     or new.email is distinct from old.email
     or new.faculty <> old.faculty
     or new.major <> old.major
     or new.graduation_year <> old.graduation_year
     or new.created_at <> old.created_at
     or new.policy_version is distinct from old.policy_version
     or new.policy_accepted_at is distinct from old.policy_accepted_at
     or new.deleted_at is distinct from old.deleted_at
     or new.verification_status is distinct from old.verification_status
     or to_jsonb(new)->'suspended_at' is distinct from to_jsonb(old)->'suspended_at'
     or to_jsonb(new)->'suspended_reason' is distinct from to_jsonb(old)->'suspended_reason'
  then
    raise exception
      'Only current_employer, current_role, industry, company and city can be updated';
  end if;

  if new.subscription_status is distinct from old.subscription_status then
    raise exception 'subscription_status can only be changed by subscribing';
  end if;
  return new;
end;
$$;
revoke execute on function alumni_profiles_restrict_update() from public, anon, authenticated;

-- account_delete: when 20261116150000 (admin remove member) is already in,
-- the body lives in account_delete_core() and clears nim only while the column
-- exists, so it is left alone. Otherwise the body here has no nim line.
do $do$
begin
  if to_regprocedure('public.account_delete_core(uuid)') is null then
    execute $sql$
create or replace function account_delete(p_profile uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_email text;
  v_files jsonb;
  n_biz integer;
  n_prod integer;
  n_jobs integer;
  n_apps integer := 0;
  n_req integer;
  n_blocks integer;
  n_notes integer;
  n_feedback integer;
  c integer;
begin
  perform assert_caller(p_profile);
  select email into v_email from alumni_profiles where id = p_profile and deleted_at is null for update;
  if not found then raise exception 'not_found'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('bucket', f.bucket, 'path', f.path)), '[]'::jsonb)
    into v_files from account_files(p_profile) f;
  insert into storage_cleanup_queue (bucket, path) select f.bucket, f.path from account_files(p_profile) f;

  delete from app_admins where profile_id = p_profile;
  delete from marketplace_admins where profile_id = p_profile;

  -- Notifications and simulated emails first (they point at jobs).
  delete from notifications
   where recipient_id = p_profile or actor_id = p_profile
      or job_post_id in (select id from job_posts where posted_by = p_profile);
  get diagnostics n_notes = row_count;
  delete from email_log
   where recipient_email = v_email
      or job_post_id in (select id from job_posts where posted_by = p_profile);

  delete from job_applications
   where applicant_id = p_profile
      or job_post_id in (select id from job_posts where posted_by = p_profile);
  get diagnostics n_apps = row_count;

  delete from marketplace_listings
   where seller_id = p_profile
      or business_id in (select id from businesses where owner_id = p_profile);
  get diagnostics n_prod = row_count;
  delete from businesses where owner_id = p_profile;
  get diagnostics n_biz = row_count;
  delete from job_posts where posted_by = p_profile;
  get diagnostics n_jobs = row_count;

  delete from contact_requests where requester_id = p_profile or target_id = p_profile;
  get diagnostics n_req = row_count;
  delete from user_blocks where blocker_id = p_profile or blocked_id = p_profile;
  get diagnostics n_blocks = row_count;
  delete from feedback_reports where profile_id = p_profile;
  get diagnostics n_feedback = row_count;
  delete from messages where sender_id = p_profile;
  delete from city_chat_messages where sender_id = p_profile;

  -- Reports they filed stay for moderation, without personal details.
  update content_reports set note = null where reporter_id = p_profile;
  update marketplace_reports set note = null where reporter = p_profile;

  update alumni_profiles set
    name = 'Deleted user',
    email = 'deleted-' || p_profile::text || '@deleted.invalid',
    faculty = '-',
    major = '-',
    graduation_year = 0,
    current_employer = null,
    "current_role" = null,
    industry = null,
    company = null,
    city = null,
    user_id = null,
    policy_version = null,
    policy_accepted_at = null,
    verification_status = 'unverified',
    deleted_at = now(),
    updated_at = now()
  where id = p_profile;

  return jsonb_build_object(
    'deleted', true,
    'removed', jsonb_build_object(
      'businesses', n_biz, 'products', n_prod, 'jobs', n_jobs, 'applications', n_apps,
      'requests', n_req, 'blocks', n_blocks, 'notifications', n_notes, 'feedback', n_feedback),
    'files', v_files);
end;
$fn$
    $sql$;
    execute $sql$revoke execute on function account_delete(uuid) from public;$sql$;
    execute $sql$grant execute on function account_delete(uuid) to anon, authenticated;$sql$;
  end if;
end $do$;

-- 3. The column and its unique key.
alter table alumni_profiles drop constraint if exists alumni_profiles_nim_key;
alter table alumni_profiles drop column if exists nim;
