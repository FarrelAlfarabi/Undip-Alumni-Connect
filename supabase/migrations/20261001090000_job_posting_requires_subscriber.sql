-- ============================================================================
-- Posting a job requires a subscriber (database side), and subscribing goes
-- through one function instead of a free-for-all column write.
--
-- Why: the app now asks the poster, not the job seeker, to subscribe. Until
-- now that was only a screen in the app. Anyone with the public anon key
-- could insert into job_posts, and could set their own subscription_status.
--
-- What this adds:
--   1. A BEFORE INSERT trigger on job_posts: when the caller is anon or
--      authenticated, posted_by must be a subscribed alumni profile.
--      The dashboard, service_role and seed files are not affected.
--   2. alumni_profiles.subscription_status can no longer be changed by
--      anon/authenticated with a plain UPDATE.
--   3. demo_subscribe(p_profile): the only way for the app to subscribe, for
--      now. It works only while billing_settings.demo_subscriptions is true.
--      Before real payments, set it to false. After that only the dashboard
--      or service_role (a payment webhook) can subscribe anyone, and the
--      checks in 1 and in marketplace_create_listing become real.
--
-- What this does NOT do: there is still no login. While demo_subscriptions
-- is true, anyone can call demo_subscribe for any profile id, so the gate is
-- a speed bump, not security. It only becomes real with the flag off.
--
-- Not applied to any live project by whoever wrote it. Idempotent: safe to
-- re-run. Rollback: supabase/rollback_job_posting_gate.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Kill switch. One row. RLS on with no policies: anon cannot read or write it.
-- Only the SECURITY DEFINER function below reads it.
-- ----------------------------------------------------------------------------
create table if not exists billing_settings (
  singleton boolean primary key default true check (singleton),
  demo_subscriptions boolean not null default true
);
insert into billing_settings (singleton) values (true) on conflict do nothing;
alter table billing_settings enable row level security;
revoke all on billing_settings from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 1. job_posts insert requires a subscribed poster.
-- SECURITY INVOKER on purpose: current_user must be the real caller (see
-- 20260917080000_relax_rls_trigger_for_dashboard.sql). alumni_profiles SELECT
-- is open to anon, so the check can read the poster's row.
-- ----------------------------------------------------------------------------
create or replace function job_posts_require_subscriber()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if new.posted_by is null or not exists (
    select 1 from alumni_profiles
    where id = new.posted_by and subscription_status = 'subscribed'
  ) then
    raise exception 'subscriber_required';
  end if;
  return new;
end;
$$;

drop trigger if exists job_posts_require_subscriber_trigger on job_posts;
create trigger job_posts_require_subscriber_trigger
  before insert on job_posts
  for each row execute function job_posts_require_subscriber();

-- ----------------------------------------------------------------------------
-- 2. subscription_status is no longer writable by a plain UPDATE from the app.
-- Same function as before, plus one check. demo_subscribe below is SECURITY
-- DEFINER, so inside it current_user is the owner and this check is skipped.
-- ----------------------------------------------------------------------------
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
revoke execute on function job_posts_require_subscriber() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. The one way to subscribe from the app, while demo mode is on.
-- ----------------------------------------------------------------------------
create or replace function demo_subscribe(p_profile uuid)
returns alumni_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v alumni_profiles;
begin
  if not exists (select 1 from billing_settings where demo_subscriptions) then
    raise exception 'demo_subscriptions_disabled';
  end if;

  update alumni_profiles
     set subscription_status = 'subscribed'
   where id = p_profile
  returning * into v;

  if v.id is null then
    raise exception 'not_found';
  end if;
  return v;
end;
$$;

revoke execute on function demo_subscribe(uuid) from public;
grant execute on function demo_subscribe(uuid) to anon, authenticated;
