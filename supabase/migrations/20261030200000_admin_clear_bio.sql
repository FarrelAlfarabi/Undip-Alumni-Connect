-- Admin "Hapus bio" (Stage 10, 30 Oct 2026): an admin removes only the bio of a
-- reported profile. The account, name and everything else stay, and the person
-- can write a new bio. Needs alumni_profiles.bio from
-- 20261030140000_profile_bio_linkedin.sql (apply that one first).
--
-- Farrel can still clear any bio in the dashboard:
--   update alumni_profiles set bio = null where id = ...
--
-- Idempotent. Rollback: supabase/rollback_admin_clear_bio.sql
-- Not applied to the live project by this change.

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
