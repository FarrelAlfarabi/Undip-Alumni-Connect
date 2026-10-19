-- Undo 20261019110000_city_whatsapp_groups.sql. Safe to run twice.
-- Deletes every saved city WhatsApp link. Export them from the dashboard first
-- if you want to keep them.
drop function if exists city_whatsapp_group_set(uuid, text, text);
drop function if exists city_whatsapp_groups_list(uuid);
drop table if exists city_whatsapp_groups;
