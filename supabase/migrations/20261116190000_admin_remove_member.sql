-- Admin "Hapus anggota": remove a fake or left-behind account and its data.
--
-- The member's own "Hapus akun" (required by the app stores) is unchanged in
-- what it does: its body moves into account_delete_core(), which only the
-- database itself can call, and account_delete() still checks the caller
-- with assert_caller() first and then runs the same core.
--
-- admin_member_remove(p_admin, p_profile, p_reason):
--   * admin only (app_admin_assert), and only with the real sign in on;
--   * a reason is required ('reason_required');
--   * cannot remove yourself ('cannot_remove_self') or an admin
--     ('target_is_admin': remove the admin role first);
--   * runs the same removal as the member's own delete (businesses, products,
--     jobs, applications, requests, blocks, notifications, feedback, chat; the
--     profile is anonymised; files are queued in storage_cleanup_queue);
--   * writes a Riwayat row (admin_actions) in the same transaction, with the
--     profile id and the reason only (the name is erased with the account).
-- Like the member's own delete, the Supabase Auth user stays; the profile is
-- detached and its email anonymised, so that login can no longer get a code.
-- It cannot be undone. The app asks for a confirm step first.
-- Idempotent. Rollback: supabase/rollback_admin_remove_member.sql

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
  -- NIM is being removed from the database; clear it only while it exists.
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'alumni_profiles'
                and column_name = 'nim') then
    execute 'update alumni_profiles set nim = null where id = $1' using p_profile;
  end if;

  return jsonb_build_object(
    'deleted', true,
    'removed', jsonb_build_object(
      'businesses', n_biz, 'products', n_prod, 'jobs', n_jobs, 'applications', n_apps,
      'requests', n_req, 'blocks', n_blocks, 'notifications', n_notes, 'feedback', n_feedback),
    'files', v_files);
end;
$$;
revoke execute on function account_delete_core(uuid) from public, anon, authenticated;

-- The member's own delete: same checks as before, same work.
create or replace function account_delete(p_profile uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_profile);
  return account_delete_core(p_profile);
end;
$$;
revoke execute on function account_delete(uuid) from public;
grant execute on function account_delete(uuid) to anon, authenticated;

create or replace function admin_member_remove(p_admin uuid, p_profile uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_result jsonb;
begin
  if not login_required() then raise exception 'login_required'; end if;
  perform app_admin_assert(p_admin);
  if v_reason is null then raise exception 'reason_required'; end if;
  if p_profile is null or p_profile = p_admin then raise exception 'cannot_remove_self'; end if;
  perform 1 from alumni_profiles where id = p_profile and deleted_at is null;
  if not found then raise exception 'not_found'; end if;
  if exists (select 1 from app_admins where profile_id = p_profile) then
    raise exception 'target_is_admin';
  end if;
  v_result := account_delete_core(p_profile);
  insert into admin_actions (admin_id, action, target_type, target_id, detail)
    values (p_admin, 'member_remove', 'profile', p_profile::text,
            left(v_reason, 300));
  return v_result - 'files';
end;
$$;
revoke execute on function admin_member_remove(uuid, uuid, text) from public;
grant execute on function admin_member_remove(uuid, uuid, text) to anon, authenticated;
