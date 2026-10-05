-- Beta hardening 2: close the anon key's access to tables the app does not need,
-- and narrow notifications.
--
-- Before: with the public anon key anyone could read
--   * email_log             poster emails, subjects, applicant names
--   * conversations, messages, city_chat_messages
--                           every chat message ever sent (chat is hidden in the
--                           UI by chatEnabled=false, but the data was open)
--   * notifications         every row, including actor_id (who filed a report)
--                           and recipient_id (who the admins are)
--
-- After:
--   * email_log and the three chat tables: no access for anon/authenticated.
--     Triggers and SECURITY DEFINER functions still write them.
--   * notifications: no direct select or update. The app reads through
--     notifications_list(), notifications_unread_count() and
--     notifications_mark_read(). They return only the columns the screen needs.
--
-- Flipping chatEnabled to true needs the chat grants back. Rollback restores them:
-- supabase/rollback_close_anon_reads.sql. Do not flip the flag before real login.
--
-- Honest limit: the three functions still take the recipient id from the client.
-- Anyone who knows a person's id can read that person's notification titles.
-- This removes the whole-table dump and the actor_id / recipient_id leak. Real
-- login (AUTH_MIGRATION_PLAN) closes the rest.
--
-- Deploy together with the app build that calls these functions and no longer
-- has the "Emails (simulated)" screen. Idempotent.

revoke all on email_log from anon, authenticated;
revoke all on conversations from anon, authenticated;
revoke all on messages from anon, authenticated;
revoke all on city_chat_messages from anon, authenticated;
revoke all on notifications from anon, authenticated;

create or replace function notifications_list(p_recipient uuid)
returns table (
  id uuid,
  job_post_id uuid,
  title text,
  body text,
  read_at timestamptz,
  created_at timestamptz,
  type text,
  target_type text,
  target_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  select n.id, n.job_post_id, n.title, n.body, n.read_at, n.created_at,
         n.type, n.target_type, n.target_id
    from notifications n
   where p_recipient is not null
     and n.recipient_id = p_recipient
   order by n.created_at desc
$$;

-- Chat rows are counted only when asked for (the app passes chatEnabled).
create or replace function notifications_unread_count(
  p_recipient uuid,
  p_include_chat boolean default false
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
    from notifications n
   where p_recipient is not null
     and n.recipient_id = p_recipient
     and n.read_at is null
     and (
       coalesce(p_include_chat, false)
       or not (
         coalesce(n.type, '') like 'chat%'
         or coalesce(n.target_type, '') in ('conversation', 'chat')
       )
     )
$$;

-- Returns how many rows it marked.
create or replace function notifications_mark_read(p_recipient uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if p_recipient is null then
    return 0;
  end if;
  update notifications
     set read_at = now()
   where recipient_id = p_recipient
     and read_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function notifications_list(uuid) from public;
revoke execute on function notifications_unread_count(uuid, boolean) from public;
revoke execute on function notifications_mark_read(uuid) from public;
grant execute on function notifications_list(uuid) to anon, authenticated;
grant execute on function notifications_unread_count(uuid, boolean) to anon, authenticated;
grant execute on function notifications_mark_read(uuid) to anon, authenticated;
