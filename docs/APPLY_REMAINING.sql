-- ============================================================================
-- Last pieces of the free-launch migrations. Run this once in the Supabase
-- SQL Editor (the editor has no confirmation prompt; the tool I used does not
-- accept statements that delete things).
--
-- Everything else of migrations 1 to 9 is already applied. This file adds:
--   1. alumni_profiles.nim may be empty (needed so a deleted account can clear it)
--   2. user_unblock (Profile > Blocked users > Unblock)
--   3. account_delete (Profile > Delete my account)
--   4. history rows for migration 9
-- Safe to run twice.
-- ============================================================================

alter table alumni_profiles alter column nim drop not null;

create or replace function user_unblock(p_blocker uuid, p_blocked uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from user_blocks where blocker_id = p_blocker and blocked_id = p_blocked;
$$;
revoke execute on function user_unblock(uuid, uuid) from public;
grant execute on function user_unblock(uuid, uuid) to anon, authenticated;

create or replace function account_delete(p_profile uuid)
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
  c integer;
begin
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
    nim = null,
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

revoke execute on function account_delete(uuid) from public;
grant execute on function account_delete(uuid) to anon, authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261003170000', 'account_deletion_and_consent') on conflict do nothing;

-- Optional cleanup of the two old subscription objects that the migration
-- would have dropped (the old trigger is already gone if you ran migration 1
-- in the editor): nothing more to do.
