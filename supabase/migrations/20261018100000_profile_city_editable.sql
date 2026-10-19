-- ============================================================================
-- Profile save fix (18 Oct 2026): city can be edited again.
--
-- The profile editor saves city together with role, company and industry, and
-- Nearby Alumni uses it. The column lock in alumni_profiles_restrict_update()
-- listed city as read-only, so any save that changed the city (or set it for
-- the first time) failed with "Only current_employer, current_role, industry
-- and company can be updated". Same function as 20261005090000, minus the
-- city line. Everything else stays locked.
-- Idempotent. Rollback: supabase/rollback_profile_city_editable.sql
-- ============================================================================

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
