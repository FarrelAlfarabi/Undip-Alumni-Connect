-- ============================================================================
-- Restore anon-open write access alongside the real-auth RLS policies
-- (22 Sep 2026).
--
-- A separate branch (feature/production-hardening) rewrote RLS on this
-- same live database to require real Supabase Auth (auth.uid() = user_id)
-- for alumni_profiles UPDATE, job_posts INSERT, and conversations/messages
-- SELECT + INSERT. main/demo's app code has no real Supabase Auth session
-- (see 20260915120000_add_basic_rls.sql's own header comment: "the app's
-- 'log in' is a plain email match ... it never creates a Supabase Auth
-- session") -- it only ever calls these tables as anon. Once the
-- authenticated-only policies went live, anon matched zero permissive
-- policies on these operations, so Edit Employment Info, Post a Job, and
-- Messaging all started silently doing nothing (RLS filters rows, it
-- doesn't raise, so these showed up as "0 rows" / empty results, not
-- errors).
--
-- These new policies are ADDITIVE (a different name, not a replacement)
-- so the authenticated-only ones stay intact for whenever real auth
-- actually ships -- Postgres RLS policies for the same command OR
-- together, so a row is accessible if it satisfies ANY permissive policy.
-- This restores what main/demo currently need without undoing the
-- production-hardening branch's own policies.
-- ============================================================================

create policy "alumni_profiles_update_anon" on alumni_profiles
  for update using (true) with check (true);

create policy "job_posts_insert_anon" on job_posts
  for insert with check (true);

create policy "conversations_select_anon" on conversations
  for select using (true);

create policy "conversations_insert_anon" on conversations
  for insert with check (true);

create policy "messages_select_anon" on messages
  for select using (true);

create policy "messages_insert_anon" on messages
  for insert with check (true);
