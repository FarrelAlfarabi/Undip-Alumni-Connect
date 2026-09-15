-- ============================================================================
-- Let the Supabase dashboard (Table Editor / SQL Editor) edit anything.
--
-- The column-lock trigger added in 20260915120000_add_basic_rls.sql fires
-- for every role, including the dashboard's own connection (typically
-- postgres or service_role), which made routine admin edits (fixing a
-- typo in a name, correcting a city) fail with the same error meant for
-- the public anon key. Scope the restriction to just anon/authenticated
-- -- the roles the deployed app actually uses -- so the dashboard is
-- unrestricted while the public-facing anon key is still locked down
-- exactly as before.
--
-- Important: this function must be SECURITY INVOKER, not SECURITY
-- DEFINER. Inside a SECURITY DEFINER function, current_user reports the
-- function's *owner*, not the actual caller -- so a current_user check
-- there would always see the owner and never actually restrict anon.
-- (Caught this live: an initial SECURITY DEFINER version of this change
-- silently let anon edit identity fields again. Verified against the
-- live project with `set role anon` both before and after this fix.)
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

-- DELETE and INSERT on alumni_profiles are still gated by RLS policies
-- (see 20260915120000_add_basic_rls.sql), not this trigger -- the
-- dashboard's own connection already bypasses RLS by default, so no
-- change is needed there for admin editing to work.
