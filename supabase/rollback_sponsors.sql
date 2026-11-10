-- Undo 20261110130000_sponsors.sql. Safe to run twice.
-- Drops the functions and the table with its rows (Home then shows no
-- sponsor box). Uploaded files stay in the sponsor-images bucket; remove them
-- in the dashboard if wanted.
drop function if exists admin_sponsor_delete(uuid, uuid);
drop function if exists admin_sponsor_save(uuid, uuid, text, text, text, date, date, integer, boolean);
drop function if exists admin_sponsor_list(uuid);
drop function if exists home_sponsors();
drop function if exists sponsor_event(uuid, text);
drop table if exists sponsor_events;
drop table if exists sponsors;
drop policy if exists "sponsor_images_public_upload" on storage.objects;
