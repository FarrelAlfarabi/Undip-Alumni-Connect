-- Undo 20261005100000_close_anon_reads.sql. Safe to run twice.
-- Gives the anon key back the access it had: select and insert on email_log and
-- the chat tables (the policies are unchanged and still apply), select and
-- update(read_at) on notifications. Use it only if you turn chat back on, or
-- together with the previous app build.
drop function if exists notifications_list(uuid);
drop function if exists notifications_unread_count(uuid, boolean);
drop function if exists notifications_mark_read(uuid);

grant select, insert on email_log to anon, authenticated;
grant select, insert on conversations to anon, authenticated;
grant select, insert on messages to anon, authenticated;
grant select, insert on city_chat_messages to anon, authenticated;
grant select on notifications to anon, authenticated;
grant update (read_at) on notifications to anon, authenticated;
