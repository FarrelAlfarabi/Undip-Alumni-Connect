-- Undo 20261001090000_job_posting_requires_subscriber.sql. Safe to run twice.
-- Restores the column lock from 20260917080000 (subscription_status writable).
drop trigger if exists job_posts_require_subscriber_trigger on job_posts;
drop function if exists job_posts_require_subscriber();
drop function if exists demo_subscribe(uuid);
drop table if exists billing_settings;

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
      'Only current_employer, current_role, industry, company, verification_status and subscription_status can be updated';
  end if;
  return new;
end;
$$;
revoke execute on function alumni_profiles_restrict_update() from public, anon, authenticated;
