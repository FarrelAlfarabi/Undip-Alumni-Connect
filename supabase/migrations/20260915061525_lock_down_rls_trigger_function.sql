-- ============================================================================
-- Reconstructed 2026-09-30, chore/sync-migrations (Session 31): this
-- migration was applied directly to the live database on 2026-09-15
-- (version 20260915061525) but no matching file existed in any branch's
-- git history. The SQL below is the exact statement Postgres recorded in
-- supabase_migrations.schema_migrations.statements for this version --
-- nothing here is invented or guessed.
-- ============================================================================

revoke execute on function alumni_profiles_restrict_update() from anon, authenticated;
