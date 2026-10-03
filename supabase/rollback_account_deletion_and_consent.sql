-- Undo 20261003170000_account_deletion_and_consent.sql. Safe to run twice.
-- WARNING: drops the three new profile columns (consent and deleted_at) and
-- storage_cleanup_queue. Deleted accounts become visible again with their
-- placeholder data, so restore or remove them first. nim is made NOT NULL
-- again (a null nim is filled with a placeholder first).
drop function if exists account_delete(uuid);
drop function if exists account_files(uuid);
drop function if exists account_accept_policy(uuid, text);
drop table if exists storage_cleanup_queue;

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
     or new.nim <> old.nim
     or new.name <> old.name
     or new.email is distinct from old.email
     or new.faculty <> old.faculty
     or new.major <> old.major
     or new.graduation_year <> old.graduation_year
     or new.city is distinct from old.city
     or new.created_at <> old.created_at
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

drop policy if exists "alumni_profiles_select" on alumni_profiles;
create policy "alumni_profiles_select" on alumni_profiles for select using (true);
drop policy if exists "alumni_profiles_update_anon" on alumni_profiles;
create policy "alumni_profiles_update_anon" on alumni_profiles
  for update using (true) with check (true);

update alumni_profiles set nim = 'deleted-' || id::text where nim is null;
alter table alumni_profiles alter column nim set not null;
alter table alumni_profiles drop column if exists policy_version;
alter table alumni_profiles drop column if exists policy_accepted_at;
alter table alumni_profiles drop column if exists deleted_at;
