-- Undo 20261030200000_profile_bio.sql. Safe to run twice.
-- Drops the bio column (every bio is lost), the functions and the trigger, and
-- puts back the column lock from 20261018100000 (without the bio line).
drop trigger if exists alumni_profiles_clear_bio_on_delete_trigger on alumni_profiles;
drop function if exists alumni_profiles_clear_bio_on_delete();
drop function if exists admin_clear_bio(uuid, uuid);
drop function if exists profile_set_bio(uuid, text);

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
     or to_jsonb(new)->'suspended_at' is distinct from to_jsonb(old)->'suspended_at'
     or to_jsonb(new)->'suspended_reason' is distinct from to_jsonb(old)->'suspended_reason'
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

alter table alumni_profiles drop constraint if exists alumni_profiles_bio_length;
alter table alumni_profiles drop column if exists bio;
