-- ============================================================================
-- Reconstructed 2026-09-30, chore/sync-migrations (Session 31): this
-- migration was applied directly to the live database on 2026-09-15
-- (version 20260915071412) but no matching file existed in any branch's
-- git history. The SQL below is the exact statement Postgres recorded in
-- supabase_migrations.schema_migrations.statements for this version --
-- nothing here is invented or guessed.
--
-- Fixes a real bug in the original SECURITY DEFINER version of this
-- trigger function: current_user under SECURITY DEFINER always resolved
-- to the function's owner, not the calling role, so the anon/authenticated
-- restriction it was meant to enforce was silently disabled for everyone.
-- Switching to SECURITY INVOKER makes current_user reflect the actual
-- caller again.
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
