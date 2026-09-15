-- ============================================================================
-- Nearby Alumni (demo feature) — adds a city column to alumni_profiles.
--
-- DEMO SCOPE: "nearby" is simulated from this seeded city field against a
-- static hardcoded distance table in the app (lib/data/city_distances.dart),
-- not real device GPS. No location permission is ever requested from a
-- user, and no one's real location is collected or stored. This is a
-- deliberate choice: live location-sharing between alumni who may not
-- otherwise know each other has real safety implications (see
-- PROJECT_NOTES.md) that were explicitly flagged and deferred — this
-- column exists to demo the *concept* only.
-- ============================================================================

alter table alumni_profiles add column if not exists city text;

-- Extend the column-lock trigger (see 20260915120000_add_basic_rls.sql) so
-- city can't be rewritten by a stray anon request either — the app never
-- writes it, it's only ever set by seed data.
create or replace function alumni_profiles_restrict_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
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
