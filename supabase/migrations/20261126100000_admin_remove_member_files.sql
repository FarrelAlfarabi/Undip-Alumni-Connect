-- Admin "Hapus anggota" failed with HTTP 403 "not_signed_in" (test row C30).
-- Cause: account_files() checks that the caller IS that profile (the real
-- login patch adds assert_caller there), and the delete core called it, so an
-- admin deleting someone else was refused. The delete core now uses an
-- internal file list that clients cannot call. account_files() keeps its
-- check, so nobody can read another person's file paths.
-- No data is changed. Idempotent. Rollback: supabase/rollback_admin_remove_member_files.sql

create or replace function account_files_core(p_profile uuid)
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

revoke execute on function account_files_core(uuid) from public, anon, authenticated;

create or replace function account_files(p_profile uuid)
returns table (bucket text, path text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_profile);
  return query select c.bucket, c.path from account_files_core(p_profile) c;
end;
$$;

create or replace function account_delete_core(p_profile uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
begin
  select email into v_email from alumni_profiles where id = p_profile and deleted_at is null for update;
  if not found then raise exception 'not_found'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('bucket', f.bucket, 'path', f.path)), '[]'::jsonb)
    into v_files from account_files_core(p_profile) f;
  insert into storage_cleanup_queue (bucket, path) select f.bucket, f.path from account_files_core(p_profile) f;

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
$$;
revoke execute on function account_delete_core(uuid) from public, anon, authenticated;
