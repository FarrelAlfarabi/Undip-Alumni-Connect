-- Undo 20261030100000_ikafe_contacts.sql. Safe to run twice.
-- Drops the functions and the table with its rows (the app then shows the
-- built-in example contacts).
drop function if exists admin_ikafe_contact_delete(uuid, uuid);
drop function if exists admin_ikafe_contact_save(uuid, uuid, text, text, text, integer, boolean);
drop function if exists admin_ikafe_contact_list(uuid);
drop table if exists ikafe_contacts;
