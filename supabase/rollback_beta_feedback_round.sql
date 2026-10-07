-- Rollback for 20261007090000_beta_feedback_round.sql. The old function
-- bodies live in 20261003100000_business_directory.sql, 20261003130000_app_admins.sql
-- and 20261003140000_reports_and_blocks.sql: re-run those function definitions
-- after this file.
drop function if exists admin_reports_unseen_count(uuid);
drop function if exists admin_reports_mark_seen(uuid);
alter table content_reports drop column if exists admin_seen_at;
alter table marketplace_reports drop column if exists admin_seen_at;
drop function if exists business_register(uuid, text, text, text, text, text, text, boolean);
drop function if exists business_update(uuid, uuid, text, text, text, text, text, boolean);
alter table businesses drop column if exists is_personal;
