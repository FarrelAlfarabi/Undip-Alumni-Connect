-- Undo 20261105190000_notifications_clear.sql. Safe to run twice.
drop function if exists notifications_clear(uuid);
drop function if exists notification_delete(uuid, uuid);
