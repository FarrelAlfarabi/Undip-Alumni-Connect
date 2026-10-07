-- ============================================================================
-- Reconstructed 2026-09-30, chore/sync-migrations (Session 31): this
-- migration was applied directly to the live database on 2026-09-15
-- (version 20260915061544) but no matching file existed in any branch's
-- git history. The SQL below is the exact statement Postgres recorded in
-- supabase_migrations.schema_migrations.statements for this version --
-- nothing here is invented or guessed.
-- ============================================================================

-- Made conditional on 2026-10-06: the function is created by a LATER migration
-- (20260915071412 and 20260915120000), so on an empty database this statement
-- failed and a fresh project could not be built. The live database already has
-- the function, so there the revoke still runs exactly as before. The later
-- migrations revoke it again after they create it.
do $$
begin
  if to_regprocedure('alumni_profiles_restrict_update()') is not null then
    revoke execute on function alumni_profiles_restrict_update() from public;
  end if;
end $$;
