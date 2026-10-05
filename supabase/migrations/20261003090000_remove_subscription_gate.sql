-- ============================================================================
-- Free launch: no subscription (decision 1, 3 Oct 2026).
--
-- Verified alumni post jobs and apply for free, with no limit. The Rp 99.000
-- per year plan is gone. This migration:
--   1. removes the "poster must be subscribed" trigger on job_posts and puts a
--      lighter rule in its place: the poster must be a verified alumnus;
--   2. closes marketplace_create_listing (no subscriber check any more, but no
--      posting either) until the business directory opens product posting
--      (Stage 6 migration);
--   3. turns demo_subscribe off: flag off, and no execute right for the app.
--
-- KEPT on purpose (nothing is dropped): alumni_profiles.subscription_status,
-- the billing_settings table, the demo_subscribe function, and all data.
-- The column lock on subscription_status stays, so the app cannot edit it.
--
-- APPLY TOGETHER WITH the app build of this release. The old app build tells
-- people "subscribe to post"; it still works against this database for jobs,
-- but its marketplace posting will be refused with 'posting_closed'.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_remove_subscription_gate.sql
-- ============================================================================

-- 1. Job posts: verified poster instead of subscribed poster.
drop trigger if exists job_posts_require_subscriber_trigger on job_posts;
drop function if exists job_posts_require_subscriber();

-- SECURITY INVOKER on purpose: current_user must be the real caller, so the
-- dashboard, service_role and seed files are not affected.
create or replace function job_posts_require_verified_poster()
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
    where id = new.posted_by and verification_status = 'verified'
  ) then
    raise exception 'verified_poster_required';
  end if;
  return new;
end;
$$;

revoke execute on function job_posts_require_verified_poster() from public, anon, authenticated;

drop trigger if exists job_posts_require_verified_poster_trigger on job_posts;
create trigger job_posts_require_verified_poster_trigger
  before insert on job_posts
  for each row execute function job_posts_require_verified_poster();

-- 2. Marketplace posting is closed until products are tied to businesses.
create or replace function marketplace_create_listing(
  p_seller uuid,
  p_title text,
  p_description text,
  p_price_idr integer,
  p_category text,
  p_city text,
  p_image_url text,
  p_shop_url text,
  p_contact_info text
)
returns marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'posting_closed';
end;
$$;

revoke execute on function marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text) from public;
grant execute on function marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text) to anon, authenticated;

-- 3. demo_subscribe off.
update billing_settings set demo_subscriptions = false;
do $$
begin
  if to_regprocedure('demo_subscribe(uuid)') is not null then
    revoke execute on function demo_subscribe(uuid) from public, anon, authenticated;
  end if;
end $$;
