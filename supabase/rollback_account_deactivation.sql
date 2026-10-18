-- Undo 20261018130000_account_deactivation.sql. Safe to run twice.
-- Only do this together with the previous app build. Anyone deactivated at the
-- time becomes visible again (their data was never removed).
drop policy if exists "marketplace_listings_select_approved" on marketplace_listings;
create policy "marketplace_listings_select_approved" on marketplace_listings
  for select to anon, authenticated
  using (status = 'approved' and hidden_at is null and marketplace_business_visible(business_id));

create or replace function marketplace_business_visible(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_business is null
      or exists (
        select 1 from businesses
        where id = p_business and status = 'approved' and hidden_at is null
      );
$$;
drop function if exists marketplace_seller_active(uuid);

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
      and not exists (
        select 1 from user_blocks ub
        where ub.blocker_id = p_viewer and ub.blocked_id = b.owner_id
      )
    order by b.name asc;
end;
$$;

drop policy if exists "alumni_profiles_select" on alumni_profiles;
create policy "alumni_profiles_select" on alumni_profiles
  for select using (deleted_at is null);

drop function if exists account_deactivate(uuid);
drop function if exists account_reactivate(uuid);

-- Back to the 20261005090000 column lock (no deactivated_at).
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

-- The column is kept on purpose: dropping it would lose who was deactivated.
-- Drop it by hand only if you are sure: alter table alumni_profiles drop column deactivated_at;
