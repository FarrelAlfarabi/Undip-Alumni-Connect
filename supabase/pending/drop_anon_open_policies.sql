-- ============================================================================
-- PENDING, DO NOT APPLY YET. Deliberately NOT in supabase/migrations/ so that
-- `supabase db push` can never apply it by accident.
--
-- What this does: removes the anon-open policies added by
-- 20260922120000_restore_anon_write_access.sql. Those policies are
-- `using (true)` for role public, and Postgres ORs permissive policies
-- together, so while they exist the real-auth policies from
-- rewrite_rls_real_auth protect nothing (anyone with the anon key can read
-- all messages, edit any profile, post jobs as anyone).
--
-- Apply ONLY when ALL of these are true:
--   1. The real-auth app build (this branch's lib/ changes) is what users run.
--      Old builds log in by email match only, with no Supabase Auth session,
--      and will silently break (0 rows / empty lists) once this runs.
--   2. Every alumni_profiles row users need has user_id linked
--      (claim_alumni_profile() has run for them).
--   3. You have a recent backup / can re-create the policies (see the
--      rollback block at the bottom).
--
-- After applying, verify as anon (no auth session), each must return 0 rows
-- or be rejected:
--   select count(*) from messages;
--   select count(*) from conversations;
--   update alumni_profiles set full_name = full_name where false;  -- no error
--   -- then try a real update with the anon key from the app: expect 0 rows
--   insert into job_posts (...) -- expect RLS violation
-- And verify as a logged-in user: own conversations/messages visible, own
-- profile editable, someone else's not.
--
-- Not covered here (still open to everyone, flagged in PROJECT_NOTES.md):
-- notifications, job_applications, city_chat_messages, email_log.
-- ============================================================================

begin;

drop policy if exists "alumni_profiles_update_anon" on alumni_profiles;
drop policy if exists "job_posts_insert_anon"       on job_posts;
drop policy if exists "conversations_select_anon"   on conversations;
drop policy if exists "conversations_insert_anon"   on conversations;
drop policy if exists "messages_select_anon"        on messages;
drop policy if exists "messages_insert_anon"        on messages;

commit;

-- ----------------------------------------------------------------------------
-- ROLLBACK (re-opens everything again; use if the app breaks after applying)
-- ----------------------------------------------------------------------------
-- create policy "alumni_profiles_update_anon" on alumni_profiles
--   for update using (true) with check (true);
-- create policy "job_posts_insert_anon" on job_posts
--   for insert with check (true);
-- create policy "conversations_select_anon" on conversations
--   for select using (true);
-- create policy "conversations_insert_anon" on conversations
--   for insert with check (true);
-- create policy "messages_select_anon" on messages
--   for select using (true);
-- create policy "messages_insert_anon" on messages
--   for insert with check (true);
