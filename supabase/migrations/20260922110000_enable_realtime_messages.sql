-- ============================================================================
-- Realtime messaging, stage 3: let the messages table broadcast Postgres
-- Changes so chat_screen.dart can subscribe instead of manually refreshing.
--
-- Supabase Realtime's Postgres Changes feature respects each table's RLS
-- SELECT policy per subscriber — since messages_select (previous migration)
-- now correctly scopes to "you're a participant in this conversation",
-- a Realtime subscription automatically only receives inserts for
-- conversations the subscribing user is actually part of. No separate
-- authorization layer needed for the realtime channel itself.
-- ============================================================================

alter table messages replica identity full;

alter publication supabase_realtime add table messages;
