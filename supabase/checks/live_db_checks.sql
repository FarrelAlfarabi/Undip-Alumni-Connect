-- Read-only checks for a Supabase project: is the database in the state the
-- current app build expects, and are the beta hardening changes really there?
--
-- Run it in the Supabase SQL editor against the project you are about to give
-- to testers. It only SELECTs from the catalog. Every row is one check:
--   ok = true   fine
--   ok = false  fix before testers use the build (detail says what is missing)
--
-- Why not trust the migration history table: supabase/APPLY_REMAINING.sql
-- registers versions as applied after pasting statements by hand, and a tool
-- that refuses statements containing "drop" may have skipped parts. These
-- checks look at the real objects instead.
--
-- Also run by supabase/tests/run_beta_local.sh: every row must be ok on the fully
-- migrated local database, and some must be false after the rollbacks.

with
fn(name) as (
  values
    ('verify_alumni_email'), ('notifications_list'), ('notifications_unread_count'),
    ('notifications_mark_read'), ('account_delete'), ('account_files'),
    ('account_accept_policy'), ('contact_request_send'), ('content_report_create'),
    ('business_register'), ('is_app_admin'), ('user_block'), ('marketplace_create_listing')
),
tbl(name) as (
  values
    ('app_admins'), ('businesses'), ('contact_requests'), ('content_reports'),
    ('user_blocks'), ('feedback_reports'), ('storage_cleanup_queue'), ('posting_plans')
),
closed(name) as (
  values ('email_log'), ('notifications'), ('conversations'), ('messages'), ('city_chat_messages')
)
select check_name, ok, detail from (
  -- 1. The functions the app calls exist.
  select 'function ' || f.name as check_name,
         exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname = 'public' and p.proname = f.name) as ok,
         'missing: apply the migration that creates it' as detail
    from fn f
  union all
  -- 2. The tables exist.
  select 'table ' || t.name,
         to_regclass('public.' || t.name) is not null,
         'missing: apply the migration that creates it'
    from tbl t
  union all
  -- 3. Account deletion and consent columns.
  select 'alumni_profiles.' || c.col,
         exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'alumni_profiles' and column_name = c.col),
         'missing: apply 20261003170000_account_deletion_and_consent.sql'
    from (values ('policy_version'), ('policy_accepted_at'), ('deleted_at')) c(col)
  union all
  -- 4. The old subscription gate must be gone, or nobody can post a job.
  select 'old job_posts subscriber trigger is gone',
         not exists (select 1 from pg_trigger
                      where tgrelid = 'public.job_posts'::regclass
                        and tgname = 'job_posts_require_subscriber_trigger'),
         'still there: it blocks every job post. Run 20261003090000_remove_subscription_gate.sql'
  union all
  select 'anon cannot call demo_subscribe',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'public' and p.proname = 'demo_subscribe'
                        and has_function_privilege('anon', p.oid, 'execute')),
         'anon can still call it: apply 20261003090000_remove_subscription_gate.sql'
  union all
  -- 5. verification_status is locked against the app.
  select 'verification_status is locked for the app',
         coalesce((select pg_get_functiondef(p.oid) like '%verification_status is distinct from%'
                     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                    where n.nspname = 'public' and p.proname = 'alumni_profiles_restrict_update'
                    limit 1), false),
         'the column lock does not cover it: apply 20261005090000_lock_verification_status.sql'
  union all
  -- 6. Deleted people are hidden from reads.
  select 'alumni_profiles read policy hides deleted people',
         exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'alumni_profiles'
                    and cmd = 'SELECT' and qual like '%deleted_at%'),
         'apply 20261003170000_account_deletion_and_consent.sql'
  union all
  -- 7. Tables the app does not need are closed to the anon key.
  select 'anon cannot read ' || c.name,
         to_regclass('public.' || c.name) is null
           or not has_table_privilege('anon', 'public.' || c.name, 'select'),
         'anon can still read it: apply 20261005100000_close_anon_reads.sql'
    from closed c
  union all
  -- 8. Internal helpers are not callable by the anon key.
  select 'anon cannot call notify_create',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'public' and p.proname = 'notify_create'
                        and has_function_privilege('anon', p.oid, 'execute')),
         'anon can call it: it creates notifications for anyone'
) checks
order by ok, check_name;
