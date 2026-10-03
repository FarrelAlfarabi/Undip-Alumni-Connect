-- Undo 20261003100000_business_directory.sql. Safe to run twice.
-- WARNING: this deletes the businesses table and every registered business.
-- Later migrations (marketplace business link, admin, reports, notifications)
-- must be rolled back first, newest first.
drop function if exists business_directory(uuid);
drop function if exists business_my(uuid);
drop function if exists business_update(uuid, uuid, text, text, text, text, text);
drop function if exists business_register(uuid, text, text, text, text, text, text);
drop function if exists business_is_verified(uuid);
drop table if exists businesses cascade;
drop function if exists businesses_lock_columns();
drop function if exists businesses_prepare();
drop function if exists normalize_link(text);
