-- Real login switch: require_login = 'on' (13 Nov 2026).
-- Same SQL as supabase/cutover_real_login.sql, shipped as a migration because
-- the database connector's confirmation prompt could not be answered, and the
-- deploy workflow is the approved way to reach live. Farrel approved the
-- cutover on 13 Nov 2026 after the production build (REAL_LOGIN=true) and the
-- email code login were tested.
-- The test runners (run_beta_local.sh, run_fresh_chain.sh) leave this file out
-- of the main chain, because the beta tests run with the switch off, and
-- apply it on its own at the end of run_fresh_chain.sh.
-- Idempotent. Rollback: supabase/rollback_real_login_cutover.sql

update app_settings set value = 'on' where key = 'require_login';

drop policy if exists "alumni_profiles_update_anon" on alumni_profiles;
drop policy if exists "job_posts_insert_anon" on job_posts;
drop policy if exists "conversations_select_anon" on conversations;
drop policy if exists "conversations_insert_anon" on conversations;
drop policy if exists "messages_select_anon" on messages;
drop policy if exists "messages_insert_anon" on messages;

revoke execute on function verify_alumni_email(text) from anon, authenticated;
