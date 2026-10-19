-- Undo 20261018110000_admin_announcements.sql. Safe to run twice.
-- Announcements already posted stay in the table.
drop function if exists admin_announcement_create(uuid, text, text);
drop function if exists admin_announcement_list(uuid);
