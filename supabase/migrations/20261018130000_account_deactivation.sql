-- ============================================================================
-- Account deactivation: hide a person without deleting anything.
--
-- Why: "Delete my account" is the only way to remove data, and it cannot be
-- undone. Deactivate is the softer option next to it. It does NOT replace
-- deletion (Apple 5.1.1(v) and Google Play both require real deletion in the
-- app; deactivation alone does not count).
--
-- What this adds:
--   * alumni_profiles.deactivated_at (null = active). The app cannot write it
--     directly; only account_deactivate / account_reactivate can.
--   * account_deactivate(p_profile), account_reactivate(p_profile). Both call
--     assert_caller first, so once real login is on a person can only act on
--     their own profile.
--   * Hiding. A deactivated person is left out of:
--       - the alumni_profiles select policy (Members, Nearby Alumni), but only
--         once real login is ON; before that the app's own filter hides them,
--         because without a login the database cannot tell who is asking,
--         and the person must still be able to find their row to come back;
--       - business_directory() (their businesses);
--       - marketplace listings (their products).
--     Nothing is removed. Job posts, contact requests and notifications are
--     left alone on purpose ("blocks nothing else").
--   * Honest limit: until real login is ON, this is a hide in the app, not
--     privacy. The database cannot tell who is calling, so deactivated rows
--     (including email and NIM) stay readable through the API, and anyone
--     holding a profile id can call account_deactivate / account_reactivate
--     for that person. Both close once real login is on (assert_caller).
--   * Signing in again calls account_reactivate (done by the app).
--
-- Not the same as suspend: suspend is an admin action on a business
-- (businesses.status). This is the person's own choice.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_account_deactivation.sql
-- ============================================================================

alter table alumni_profiles add column if not exists deactivated_at timestamptz;

-- ---------------------------------------------------------- column lock ---
-- Same lock as 20261005090000, plus deactivated_at.
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
     or new.deactivated_at is distinct from old.deactivated_at
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

-- ------------------------------------------------------------ functions ---
create or replace function account_deactivate(p_profile uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_profile);
  if not business_is_verified(p_profile) then raise exception 'not_verified'; end if;
  update alumni_profiles
     set deactivated_at = coalesce(deactivated_at, now())
   where id = p_profile and deleted_at is null;
  if not found then raise exception 'not_found'; end if;
end;
$$;

create or replace function account_reactivate(p_profile uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_profile);
  update alumni_profiles
     set deactivated_at = null
   where id = p_profile and deleted_at is null;
  if not found then raise exception 'not_found'; end if;
end;
$$;

revoke execute on function account_deactivate(uuid) from public;
revoke execute on function account_reactivate(uuid) from public;
grant execute on function account_deactivate(uuid) to anon, authenticated;
grant execute on function account_reactivate(uuid) to anon, authenticated;

-- --------------------------------------------------------------- hiding ---
-- Members and Nearby Alumni read alumni_profiles. With real login on, a
-- deactivated row is visible only to its own owner.
drop policy if exists "alumni_profiles_select" on alumni_profiles;
create policy "alumni_profiles_select" on alumni_profiles
  for select using (
    deleted_at is null
    and (deactivated_at is null or not login_required() or user_id = auth.uid())
  );

-- Business directory: same as 20261003140000, plus owners who are active.
-- assert_caller stays first (20261013120000 added it to this function).
create or replace function business_directory(p_viewer uuid)
returns table (
  id uuid,
  owner_id uuid,
  name text,
  description text,
  category text,
  social_link text,
  website_link text,
  approved_band text,
  created_at timestamptz,
  owner_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_viewer);
  if not business_is_verified(p_viewer) then raise exception 'not_verified'; end if;
  return query
    select b.id, b.owner_id, b.name, b.description, b.category, b.social_link,
           b.website_link, b.approved_band, b.created_at, p.name
    from businesses b
    join alumni_profiles p on p.id = b.owner_id
    where b.status = 'approved'
      and b.hidden_at is null
      and p.deactivated_at is null
      and not exists (
        select 1 from user_blocks ub
        where ub.blocker_id = p_viewer and ub.blocked_id = b.owner_id
      )
    order by b.name asc;
end;
$$;

-- Marketplace: products of a deactivated seller, or of a deactivated
-- business owner, are not shown.
create or replace function marketplace_seller_active(p_seller uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1 from alumni_profiles where id = p_seller and deactivated_at is not null
  );
$$;
-- Only the policy below needs this; the grant lets anyone probe whether an id
-- is a deactivated profile, which they can already read before real login.
revoke execute on function marketplace_seller_active(uuid) from public;
grant execute on function marketplace_seller_active(uuid) to anon, authenticated;

create or replace function marketplace_business_visible(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_business is null
      or exists (
        select 1 from businesses b
        join alumni_profiles p on p.id = b.owner_id
        where b.id = p_business and b.status = 'approved' and b.hidden_at is null
          and p.deactivated_at is null
      );
$$;

drop policy if exists "marketplace_listings_select_approved" on marketplace_listings;
create policy "marketplace_listings_select_approved" on marketplace_listings
  for select to anon, authenticated
  using (
    status = 'approved' and hidden_at is null
    and marketplace_business_visible(business_id)
    and marketplace_seller_active(seller_id)
  );
