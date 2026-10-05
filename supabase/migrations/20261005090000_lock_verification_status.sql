-- Beta hardening 1: the app can no longer write alumni_profiles.verification_status.
--
-- Before: the app marked itself verified with a plain UPDATE, and the column lock
-- trigger allowed that. Anyone with the anon key could verify any person, or
-- un-verify everybody (which also wipes every device's PIN, see AppEntry._unlock).
-- Every "verified only" check in the database depended on that column.
--
-- After: only verify_alumni_email() sets it. It matches the email ignoring case
-- and spaces, verifies a person who is 'unverified', leaves a 'failed' person
-- failed (an admin can revoke someone and it sticks), and ignores deleted people.
--
-- Honest limit: this is still an email match, not a login. Anyone who knows an
-- alumnus's email can verify as that person. It removes the bulk and by-id
-- attacks, not impersonation. Real login is the AUTH_MIGRATION_PLAN.
--
-- Deploy together with the app build that calls verify_alumni_email(). The
-- previous app build verifies with an UPDATE and will stop working.
-- Idempotent. Rollback: supabase/rollback_lock_verification_status.sql.

create or replace function verify_alumni_email(p_email text)
returns setof alumni_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  r alumni_profiles;
begin
  if p_email is null or btrim(p_email) = '' then
    return;
  end if;

  select * into r
    from alumni_profiles
   where lower(email) = lower(btrim(p_email))
     and deleted_at is null;
  if not found then
    return;
  end if;

  if r.verification_status = 'unverified' then
    update alumni_profiles
       set verification_status = 'verified'
     where id = r.id
    returning * into r;
  end if;

  return next r;
end;
$$;
revoke execute on function verify_alumni_email(text) from public;
grant execute on function verify_alumni_email(text) to anon, authenticated;

-- Same column lock as 20261003170000, plus verification_status.
-- SECURITY INVOKER: the dashboard, service_role and the SECURITY DEFINER
-- functions (verify_alumni_email, account_delete) are exempt.
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
     or new.verification_status is distinct from old.verification_status
  then
    raise exception
      'Only current_employer, current_role, industry and company can be updated';
  end if;

  if new.subscription_status is distinct from old.subscription_status then
    raise exception 'subscription_status can only be changed by subscribing';
  end if;
  return new;
end;
$$;
revoke execute on function alumni_profiles_restrict_update() from public, anon, authenticated;
