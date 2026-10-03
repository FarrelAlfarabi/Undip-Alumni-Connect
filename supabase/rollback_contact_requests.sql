-- Undo 20261003120000_contact_requests.sql. Safe to run twice.
-- WARNING: deletes the contact_requests table and every request in it.
-- Later migrations that use contact_requests must be rolled back first.
drop function if exists contact_request_shared_contact(uuid, uuid);
drop function if exists contact_request_respond(uuid, uuid, boolean, text);
drop function if exists contact_requests_pending_count(uuid);
drop function if exists contact_requests_outgoing(uuid);
drop function if exists contact_requests_incoming(uuid);
drop function if exists contact_request_send(uuid, uuid, text);
drop table if exists contact_requests cascade;
drop function if exists contact_requests_enforce();
