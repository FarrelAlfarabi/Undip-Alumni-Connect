-- Members can delete their own notifications: one, or all. The table stays
-- closed to the app; these functions only touch the caller's own rows.
-- Idempotent. Rollback: supabase/rollback_notifications_clear.sql
create or replace function notifications_clear(p_recipient uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  perform assert_caller(p_recipient);
  delete from notifications where recipient_id = p_recipient;
  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function notification_delete(p_recipient uuid, p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_recipient);
  delete from notifications where id = p_id and recipient_id = p_recipient;
end;
$$;

revoke execute on function notifications_clear(uuid) from public;
revoke execute on function notification_delete(uuid, uuid) from public;
grant execute on function notifications_clear(uuid) to anon, authenticated;
grant execute on function notification_delete(uuid, uuid) to anon, authenticated;
