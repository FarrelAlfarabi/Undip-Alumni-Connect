-- Undo 20261105240000_announcement_edit.sql. Safe to run twice.
drop function if exists admin_announcement_update(uuid, uuid, text, text);
