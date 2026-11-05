-- Undo 20261105200000_storage_cleanup_triggers.sql. Safe to run twice.
drop trigger if exists marketplace_listings_storage_cleanup on marketplace_listings;
drop trigger if exists businesses_storage_cleanup on businesses;
drop trigger if exists job_posts_storage_cleanup on job_posts;
drop trigger if exists job_applications_storage_cleanup on job_applications;
drop function if exists storage_cleanup_on_delete();
drop function if exists storage_cleanup_enqueue(text, text);
