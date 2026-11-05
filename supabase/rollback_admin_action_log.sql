-- Undo 20261105220000_admin_action_log.sql. Safe to run twice.
drop function if exists admin_log_action(uuid, text, text, text, text);
drop function if exists admin_actions_list(uuid);
drop table if exists admin_actions;
