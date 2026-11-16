-- Rollback of 20261116210000_admin_log_search.
drop function if exists admin_actions_search(uuid, text, text, uuid, timestamptz, integer);
drop index if exists idx_admin_actions_admin;
