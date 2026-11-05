-- Undo 20261105180000_job_close_edit.sql. Safe to run twice.
drop function if exists job_post_set_closed(uuid, uuid, boolean);
drop function if exists job_post_update(uuid, uuid, text, text, text, text);
alter table job_posts drop column if exists closed_at;
