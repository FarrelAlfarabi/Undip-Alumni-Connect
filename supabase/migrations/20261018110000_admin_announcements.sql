-- ============================================================================
-- Admin announcements: post and list from the app, admins only.
--
-- announcements keeps its RLS: everyone can read, and NO insert/update/delete
-- policy exists, so the app roles cannot write the table directly. The only
-- way in is admin_announcement_create, a SECURITY DEFINER function that
-- checks app_admins (app_admin_assert) before inserting. Title is 1 to 120
-- characters and the message 1 to 2000, after trimming (invalid_input).
-- posted_by is the admin's profile id, never taken from the caller's text.
-- admin_announcement_list adds the poster's name for the admin screen.
--
-- Same limit as every admin call: with no real login the admin id is not
-- authenticated (see 20261003130000_app_admins.sql). With real login on,
-- is_app_admin also checks the signed-in user.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_admin_announcements.sql
-- ============================================================================

create or replace function admin_announcement_create(
  p_admin uuid,
  p_title text,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text := btrim(coalesce(p_title, ''), E' \t\r\n');
  v_body text := btrim(coalesce(p_body, ''), E' \t\r\n');
  v_id uuid;
begin
  perform app_admin_assert(p_admin);
  if v_title = '' or v_body = ''
     or char_length(v_title) > 120 or char_length(v_body) > 2000 then
    raise exception 'invalid_input';
  end if;
  insert into announcements (title, body, posted_by)
    values (v_title, v_body, p_admin)
    returning id into v_id;
  return v_id;
end;
$$;

create or replace function admin_announcement_list(p_admin uuid)
returns table (
  id uuid,
  title text,
  body text,
  posted_by_name text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select a.id, a.title, a.body, p.name, a.created_at
    from announcements a
    left join alumni_profiles p on p.id = a.posted_by
    order by a.created_at desc, a.id desc;
end;
$$;

revoke execute on function admin_announcement_create(uuid, text, text) from public;
revoke execute on function admin_announcement_list(uuid) from public;
grant execute on function admin_announcement_create(uuid, text, text) to anon, authenticated;
grant execute on function admin_announcement_list(uuid) to anon, authenticated;
