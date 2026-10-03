-- ============================================================================
-- Consent and account deletion (closed beta, Stage 6G).
--
-- CONSENT
--   alumni_profiles.policy_version / policy_accepted_at record which version
--   of the privacy policy a person accepted. The app compares policy_version
--   with its own constant and shows the consent screen when they differ.
--   Only account_accept_policy() writes them (the column lock trigger blocks
--   a direct update from the app).
--
-- DELETION: account_delete(profile) does, in ONE transaction:
--   * deletes the person's businesses, products, job posts, job applications
--     (theirs, and everyone's applications to their jobs), contact requests
--     (both directions), notifications to and from them, blocks (both
--     directions), feedback reports, simulated emails to their address, chat
--     messages, and their admin row;
--   * keeps the reports they filed and reports against others, for
--     moderation, with the note removed (no personal details);
--   * clears every personal field on the profile row, sets name 'Deleted
--     user', a unique placeholder email, nim null (nim becomes nullable;
--     unique allows many nulls), faculty '-', major '-', graduation_year 0,
--     verification_status 'unverified', and deleted_at.
--   The select policy hides rows with deleted_at, so they vanish from every
--   screen, and the old email can no longer be used to verify.
--   The row itself is kept (reports and reviews point at it). You can restore
--   a person from the Ikafe list in the dashboard: set deleted_at back to
--   null and re-fill the fields.
--
--   FILES: the app tries to remove the person's files (product photos, CVs)
--   through the storage API first (best effort; with the current bucket rules
--   the app role has no delete right, so this is expected to be refused). The
--   paths are written to storage_cleanup_queue so you can delete them in the
--   dashboard (Storage) and mark them done.
--
-- HONEST LIMIT: with no real login, anyone who knows a person's profile id
-- could call account_delete for them. The typed confirmation in the app is a
-- speed bump, not security.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_account_deletion_and_consent.sql
-- ============================================================================

alter table alumni_profiles add column if not exists policy_version text;
alter table alumni_profiles add column if not exists policy_accepted_at timestamptz;
alter table alumni_profiles add column if not exists deleted_at timestamptz;
alter table alumni_profiles alter column nim drop not null;

-- Deleted rows are invisible to the app (and so are not found by email).
drop policy if exists "alumni_profiles_select" on alumni_profiles;
create policy "alumni_profiles_select" on alumni_profiles
  for select using (deleted_at is null);

drop policy if exists "alumni_profiles_update_anon" on alumni_profiles;
create policy "alumni_profiles_update_anon" on alumni_profiles
  for update using (deleted_at is null) with check (deleted_at is null);

-- Same column lock as before, plus the three new columns. SECURITY INVOKER:
-- the dashboard, service_role and the SECURITY DEFINER functions are exempt.
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
     or new.nim is distinct from old.nim
     or new.name <> old.name
     or new.email is distinct from old.email
     or new.faculty <> old.faculty
     or new.major <> old.major
     or new.graduation_year <> old.graduation_year
     or new.city is distinct from old.city
     or new.created_at <> old.created_at
     or new.policy_version is distinct from old.policy_version
     or new.policy_accepted_at is distinct from old.policy_accepted_at
     or new.deleted_at is distinct from old.deleted_at
  then
    raise exception
      'Only current_employer, current_role, industry, company and verification_status can be updated';
  end if;

  if new.subscription_status is distinct from old.subscription_status then
    raise exception 'subscription_status can only be changed by subscribing';
  end if;
  return new;
end;
$$;
revoke execute on function alumni_profiles_restrict_update() from public, anon, authenticated;

-- ------------------------------------------------------------- consent ---
create or replace function account_accept_policy(p_profile uuid, p_version text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v text := nullif(btrim(coalesce(p_version, '')), '');
begin
  if v is null or char_length(v) > 30 then raise exception 'invalid_version'; end if;
  if not business_is_verified(p_profile) then raise exception 'not_verified'; end if;
  update alumni_profiles
     set policy_version = v, policy_accepted_at = now()
   where id = p_profile and deleted_at is null;
end;
$$;

-- ------------------------------------------------------------- deletion ---
create table if not exists storage_cleanup_queue (
  id uuid primary key default gen_random_uuid(),
  bucket text not null,
  path text not null,
  created_at timestamptz not null default now(),
  done_at timestamptz
);
alter table storage_cleanup_queue enable row level security;
revoke all on storage_cleanup_queue from public, anon, authenticated;

-- Storage paths of this person's own files: product photos (taken from the
-- public image URL) and CVs they attached to applications.
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
  where a.applicant_id = p_profile and a.cv_path is not null and a.cv_path <> '';
$$;

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

revoke execute on function account_accept_policy(uuid, text) from public;
revoke execute on function account_files(uuid) from public;
revoke execute on function account_delete(uuid) from public;
grant execute on function account_accept_policy(uuid, text) to anon, authenticated;
grant execute on function account_files(uuid) to anon, authenticated;
grant execute on function account_delete(uuid) to anon, authenticated;
