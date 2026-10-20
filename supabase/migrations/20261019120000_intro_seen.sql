-- First-login intro (19 Oct 2026): remember on the server that a person has
-- seen the Marketplace and Business intro, so it shows once per person and
-- not once per device or browser.
--
--   * alumni_profiles.intro_seen_at: null = not seen yet, a time = seen then.
--     Nobody is backfilled: the database cannot know who saw the intro on a
--     device. The app skips the intro when a device remembers it and saves
--     that here, so people who already saw it are not shown it again.
--   * account_mark_intro_seen(profile): sets the time once. Later calls keep
--     the first time.
--   * account_intro_seen(profile): true when it is set.
--   Both check the caller with assert_caller (same as the other account
--   functions): only the signed-in owner of the profile may use them once
--   require_login is on.
--   * The app reads its own value through account_intro_seen() and never
--     selects the column, so the app also works before this migration is
--     applied (the call fails, the app falls back to its local flag).
--   * The column has the same select grant as the other profile columns
--     (20261018120000 and supabase/checks/live_db_checks.sql require it).
--
-- Idempotent. Rollback: supabase/rollback_intro_seen.sql
-- Not applied to the live project by this change. Farrel applies it in the
-- SQL Editor.

alter table alumni_profiles add column if not exists intro_seen_at timestamptz;

-- Same rule as every other column (20261018120000): the app roles can read it.
-- It is only a time. The app itself never selects it; it asks through
-- account_intro_seen(), so the app also works before this is applied.
grant select (intro_seen_at) on alumni_profiles to anon, authenticated;

create or replace function account_mark_intro_seen(p_profile uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_profile is null then
    return;
  end if;
  perform assert_caller(p_profile);
  update alumni_profiles
     set intro_seen_at = coalesce(intro_seen_at, now())
   where id = p_profile and deleted_at is null;
end;
$$;
revoke execute on function account_mark_intro_seen(uuid) from public;
grant execute on function account_mark_intro_seen(uuid) to anon, authenticated;

create or replace function account_intro_seen(p_profile uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_profile is null then
    return false;
  end if;
  perform assert_caller(p_profile);
  return coalesce(
    (select intro_seen_at is not null from alumni_profiles
      where id = p_profile and deleted_at is null),
    false);
end;
$$;
revoke execute on function account_intro_seen(uuid) from public;
grant execute on function account_intro_seen(uuid) to anon, authenticated;
