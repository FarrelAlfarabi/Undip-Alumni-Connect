-- ============================================================================
-- Rollback for the marketplace demo. Removes ONLY marketplace objects:
-- functions, tables (listings, reports, admins), the `marketplace` storage
-- bucket policies and bucket. Touches nothing else. Safe to run twice.
--
-- Not a migration (it is not in supabase/migrations/): run it by hand when
-- you want the marketplace gone. Deletes all marketplace data.
-- ============================================================================

drop function if exists marketplace_report_counts(uuid);
drop function if exists marketplace_review_listing(uuid, uuid, text, text);
drop function if exists marketplace_admin_pending(uuid);
drop function if exists marketplace_my_listings(uuid);
drop function if exists marketplace_delete_listing(uuid, uuid);
drop function if exists marketplace_set_sold(uuid, uuid);
drop function if exists marketplace_update_listing(uuid, uuid, text, text, integer, text, text, text, text, text);
drop function if exists marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text);
drop function if exists marketplace_is_admin(uuid);

drop table if exists marketplace_reports;
drop table if exists marketplace_listings;
drop table if exists marketplace_admins;

drop policy if exists "marketplace_public_read" on storage.objects;
drop policy if exists "marketplace_public_upload" on storage.objects;

-- Storage refuses to drop a bucket that still has files. Delete the bucket
-- in the dashboard (Storage > marketplace > delete) if it has uploads; this
-- only removes it when empty.
delete from storage.buckets b
where b.id = 'marketplace'
  and not exists (select 1 from storage.objects o where o.bucket_id = 'marketplace');
