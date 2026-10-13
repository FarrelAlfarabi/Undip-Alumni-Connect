-- ============================================================================
-- CUTOVER: turn real login ON. Run by hand in the Supabase SQL editor, once,
-- when the app build made with --dart-define=REAL_LOGIN=true is what people
-- use. NOT a migration: do not put it in supabase/migrations.
--
-- Before you run it (see docs/REAL_LOGIN.md for the full list):
--   1. 20261013120000_real_login.sql is applied.
--   2. Supabase Auth: email sign in on, "Confirm email" on, email template
--      shows {{ .Token }}, and a real SMTP sender is set up (the built in
--      sender is limited to a few emails per hour).
--   3. The new app build is live. The OLD build stops working after this:
--      it cannot sign in and every action returns not_signed_in.
--
-- What it does:
--   * require_login = 'on': every function that trusted an id sent by the
--     app now needs a signed in caller who IS that profile; admin checks too.
--   * Drops the open (anonymous) write policies on alumni_profiles,
--     job_posts, conversations and messages. The signed in policies from
--     20260922025148_rewrite_rls_real_auth.sql stay, so a person can still
--     edit their own profile and post jobs as themselves.
--   * Takes verify_alumni_email (the old email only check, which returns the
--     whole profile to anyone who knows an email) away from the app roles.
--
-- Rollback: supabase/rollback_cutover_real_login.sql
-- ============================================================================

update app_settings set value = 'on' where key = 'require_login';

drop policy if exists "alumni_profiles_update_anon" on alumni_profiles;
drop policy if exists "job_posts_insert_anon" on job_posts;
drop policy if exists "conversations_select_anon" on conversations;
drop policy if exists "conversations_insert_anon" on conversations;
drop policy if exists "messages_select_anon" on messages;
drop policy if exists "messages_insert_anon" on messages;

revoke execute on function verify_alumni_email(text) from anon, authenticated;
