-- Undo 20261126120000_business_edit_requests.sql. Safe to run twice.
-- Requests still waiting are deleted with the table. Businesses keep the
-- values that were already approved.
drop function if exists admin_business_edit_decide(uuid, uuid, text, text);
drop function if exists admin_business_edit_pending_count(uuid);
drop function if exists admin_business_edit_requests(uuid, text);
drop function if exists business_edit_request_my(uuid);
drop function if exists business_edit_request_cancel(uuid, uuid);
drop function if exists business_edit_request_submit(uuid, uuid, text, text, text, text, text, boolean, text, text);
drop table if exists business_edit_requests;
