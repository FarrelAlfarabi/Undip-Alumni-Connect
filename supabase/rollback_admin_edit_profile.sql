-- Undo 20261116120000_admin_edit_profile.sql. Safe to run twice.
-- Profiles an admin already edited keep their new values.
drop function if exists admin_update_profile(uuid, uuid, jsonb);
drop function if exists admin_members_search(uuid, text);
