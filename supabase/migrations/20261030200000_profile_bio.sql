-- Profile bio (Stage 10, 30 Oct 2026): a short free text about yourself, shown
-- on your profile and on other members' view of it.
--
--   * alumni_profiles.bio: nullable, 200 characters at most (check constraint).
--     Members can read it like every other profile column (grant below, and
--     lib/data/profile_columns.dart lists it). Deploy this migration BEFORE or
--     WITH the app build: the new build selects the column, so a build that
--     reaches a database without it fails every profile read.
--   * profile_set_bio(profile, bio): the only way the app changes a bio. Checks
--     the caller (assert_caller, same as the other account functions), a
--     verified and not deleted profile, trims, turns empty into null, refuses
--     more than 200 characters and control characters (a line break is fine).
--   * alumni_profiles_restrict_update() now also locks bio, so the app roles
--     cannot skip those checks with a plain UPDATE. Same function as
--     20261018100000 plus one line.
--   * admin_clear_bio(admin, profile): an admin removes only the bio. The
--     account, the name and everything else stay. Reached from the Reports
--     screen ("Hapus bio") on a reported profile. Farrel can still edit any
--     bio in the dashboard: update alumni_profiles set bio = null where id = ...
--   * Deleting an account clears the bio: a trigger blanks it when deleted_at
--     is set, so account_delete() does not need to be copied here.
--
-- Idempotent. Rollback: supabase/rollback_profile_bio.sql
-- Not applied to the live project by this change. Farrel applies it in the
-- SQL Editor.

alter table alumni_profiles add column if not exists bio text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'alumni_profiles_bio_length'
       and conrelid = 'public.alumni_profiles'::regclass
  ) then
    alter table alumni_profiles
      add constraint alumni_profiles_bio_length
      check (bio is null or char_length(bio) <= 200);
  end if;
end $$;

-- Same rule as every other column (20261018120000): the app roles can read it.
grant select (bio) on alumni_profiles to anon, authenticated;

-- ---- the column lock, plus bio ---------------------------------------------
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
     or new.created_at <> old.created_at
     or new.policy_version is distinct from old.policy_version
     or new.policy_accepted_at is distinct from old.policy_accepted_at
     or new.deleted_at is distinct from old.deleted_at
     or new.verification_status is distinct from old.verification_status
     -- Suspension columns come from 20261018090000. Read through jsonb so this
     -- function also works if that migration is not applied (yet).
     or to_jsonb(new)->'suspended_at' is distinct from to_jsonb(old)->'suspended_at'
     or to_jsonb(new)->'suspended_reason' is distinct from to_jsonb(old)->'suspended_reason'
     -- The bio changes only through profile_set_bio() and admin_clear_bio().
     or new.bio is distinct from old.bio
  then
    raise exception
      'Only current_employer, current_role, industry, company and city can be updated (bio: use profile_set_bio)';
  end if;

  if new.subscription_status is distinct from old.subscription_status then
    raise exception 'subscription_status can only be changed by subscribing';
  end if;
  return new;
end;
$$;
revoke execute on function alumni_profiles_restrict_update() from public, anon, authenticated;

-- ---- profile_set_bio -------------------------------------------------------
create or replace function profile_set_bio(p_profile uuid, p_bio text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v text := nullif(regexp_replace(coalesce(p_bio, ''), '^\s+|\s+$', '', 'g'), '');
begin
  perform assert_caller(p_profile);
  if p_profile is null or not exists (
    select 1 from alumni_profiles
     where id = p_profile and deleted_at is null and verification_status = 'verified'
  ) then
    raise exception 'not_verified';
  end if;
  if v is not null then
    if char_length(v) > 200 then
      raise exception 'bio_too_long';
    end if;
    -- Control characters (tabs and line breaks are allowed). Text cannot hold
    -- a null character at all.
    -- Also C1 controls, zero-width characters, line/paragraph separators and
    -- bidi overrides, which would hide or reverse text for other members.
    if v ~ '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\u200B-\u200F\u2028-\u202E\u2060-\u2064\uFEFF]' then
      raise exception 'bio_invalid';
    end if;
  end if;
  update alumni_profiles set bio = v, updated_at = now() where id = p_profile;
end;
$$;
revoke execute on function profile_set_bio(uuid, text) from public;
grant execute on function profile_set_bio(uuid, text) to anon, authenticated;

-- ---- admin_clear_bio -------------------------------------------------------
create or replace function admin_clear_bio(p_admin uuid, p_profile uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  update alumni_profiles set bio = null, updated_at = now() where id = p_profile;
  if not found then
    raise exception 'not_found';
  end if;
end;
$$;
revoke execute on function admin_clear_bio(uuid, uuid) from public;
grant execute on function admin_clear_bio(uuid, uuid) to anon, authenticated;

-- ---- account deletion clears the bio ---------------------------------------
create or replace function alumni_profiles_clear_bio_on_delete()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.deleted_at is not null then
    new.bio := null;
  end if;
  return new;
end;
$$;
revoke execute on function alumni_profiles_clear_bio_on_delete() from public, anon, authenticated;

drop trigger if exists alumni_profiles_clear_bio_on_delete_trigger on alumni_profiles;
create trigger alumni_profiles_clear_bio_on_delete_trigger
  before update on alumni_profiles
  for each row execute function alumni_profiles_clear_bio_on_delete();
