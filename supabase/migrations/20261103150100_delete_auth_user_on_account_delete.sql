-- ============================================================================
-- Account deletion also removes the Supabase Auth user (store requirement:
-- deleting an account must delete the login, not only the profile data).
--
-- account_delete() already clears the profile and sets deleted_at. This adds a
-- trigger: the moment a profile gets deleted_at (from the app, or by hand in
-- the dashboard), its auth.users row is deleted, which also ends its sessions.
-- The profile row stays (reports point at it) with user_id empty.
--
-- If the person comes back later, they sign in with a new email code and the
-- normal link-by-email step creates a fresh link. Restoring a profile in the
-- dashboard (deleted_at back to null) does not bring the old login back.
--
-- Idempotent. Rollback: supabase/rollback_delete_auth_user_on_account_delete.sql
-- ============================================================================

create or replace function alumni_profiles_delete_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.user_id is not null then
    -- The foreign key on user_id must be released before the auth row goes.
    update alumni_profiles set user_id = null where id = new.id and user_id is not null;
    delete from auth.users where id = old.user_id;
  end if;
  return null;
end;
$$;

revoke execute on function alumni_profiles_delete_auth_user() from public, anon, authenticated;

drop trigger if exists alumni_profiles_delete_auth_user on alumni_profiles;
create trigger alumni_profiles_delete_auth_user
  after update of deleted_at on alumni_profiles
  for each row
  when (old.deleted_at is null and new.deleted_at is not null)
  execute function alumni_profiles_delete_auth_user();
