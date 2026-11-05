-- Admins can edit a posted announcement (title and message). The same checks
-- as posting: admin only, both fields filled, 120 and 2000 characters at most.
-- The post keeps its date, its author and its place in the Home order.
-- Rollback: supabase/rollback_announcement_edit.sql
create or replace function admin_announcement_update(
  p_admin uuid,
  p_id uuid,
  p_title text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text := btrim(coalesce(p_title, ''), E' \t\r\n');
  v_body text := btrim(coalesce(p_body, ''), E' \t\r\n');
begin
  perform assert_caller(p_admin);
  perform app_admin_assert(p_admin);
  if v_title = '' or v_body = ''
     or char_length(v_title) > 120 or char_length(v_body) > 2000 then
    raise exception 'invalid_input';
  end if;
  update announcements set title = v_title, body = v_body where id = p_id;
  if not found then raise exception 'not_found'; end if;
end;
$$;
revoke execute on function admin_announcement_update(uuid, uuid, text, text) from public;
grant execute on function admin_announcement_update(uuid, uuid, text, text) to anon, authenticated;
