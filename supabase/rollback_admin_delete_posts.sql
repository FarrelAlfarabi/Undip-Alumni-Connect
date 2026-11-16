-- Rollback of 20261116200000_admin_delete_posts. Deleted items stay deleted.
drop function if exists admin_job_delete(uuid, uuid, text);
drop function if exists admin_listing_delete(uuid, uuid, text);
