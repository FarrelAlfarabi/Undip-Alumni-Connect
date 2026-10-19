-- Hide NIM from other members.
--
-- Before: the app and the anon/authenticated API roles could read every column
-- of alumni_profiles, NIM included, for every verified alumnus. The Members
-- list and profile screens showed it, and the API returned it even where the
-- screen did not.
--
-- After:
--   * anon and authenticated can read every alumni_profiles column EXCEPT nim.
--     "select *", "select nim", filtering or sorting on nim: permission denied.
--   * profile_nim(viewer, profile) returns the NIM to the person it belongs to
--     and to app admins. Everyone else gets null.
--   * The dashboard (postgres), service_role, seed files and SECURITY DEFINER
--     functions are unchanged: Farrel still sees and edits every NIM.
--
-- The app must ask for explicit columns (no "select *") on alumni_profiles.
-- Deploy together with the app build that does. The previous build breaks on
-- every profile read.
--
-- A NEW alumni_profiles column is NOT readable until it is granted:
--   grant select (new_column) on alumni_profiles to anon, authenticated;
-- supabase/checks/live_db_checks.sql flags a column that was forgotten.
--
-- Not covered here: verify_alumni_email() returns the whole row (NIM too) to
-- anyone who types a known email. That is the email-match limit written down in
-- 20261005090000_lock_verification_status.sql. Real login (claim_alumni_profile)
-- returns only the signed-in person's own row.
--
-- Idempotent. Rollback: supabase/rollback_hide_nim.sql.

revoke select on alumni_profiles from anon, authenticated;

do $$
declare
  cols text;
begin
  select string_agg(format('%I', column_name), ', ' order by ordinal_position)
    into cols
    from information_schema.columns
   where table_schema = 'public'
     and table_name = 'alumni_profiles'
     and column_name <> 'nim';
  execute format('grant select (%s) on alumni_profiles to anon, authenticated', cols);
end $$;

create or replace function profile_nim(p_viewer uuid, p_profile uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v text;
begin
  if p_viewer is null or p_profile is null then
    return null;
  end if;
  perform assert_caller(p_viewer);
  if p_viewer <> p_profile and not is_app_admin(p_viewer) then
    return null;
  end if;
  select nim into v from alumni_profiles
   where id = p_profile and deleted_at is null;
  return v;
end;
$$;
revoke execute on function profile_nim(uuid, uuid) from public;
grant execute on function profile_nim(uuid, uuid) to anon, authenticated;
