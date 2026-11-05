-- Undo 20261105100000_delete_own_content.sql. Safe to run twice.
-- Content already deleted does not come back.
drop function if exists business_delete(uuid, uuid);
drop function if exists job_post_delete(uuid, uuid);
drop function if exists admin_announcement_delete(uuid, uuid);
