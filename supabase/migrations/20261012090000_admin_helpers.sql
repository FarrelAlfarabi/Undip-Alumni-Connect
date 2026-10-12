-- ============================================================================
-- Easier admin management from the Supabase dashboard.
--
-- Run these in the dashboard SQL editor (they work for the owner only; the app
-- roles cannot call them):
--
--   select add_app_admin('person@example.com', 'Name or note');
--   select remove_app_admin('person@example.com');
--   select * from list_app_admins();
--
-- add_app_admin / remove_app_admin return a word: added, already_admin,
-- removed or not_admin. add_app_admin raises no_profile_with_email when no
-- profile has that email (the person must sign up first), instead of the
-- silent "INSERT 0 0", and more_than_one_profile_with_email when emails
-- differ only by capitals (fix the data first). The service key cannot call
-- them either.
--
-- The app_admins table is unchanged. Editing it by hand still works.
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_admin_helpers.sql
-- ============================================================================

create or replace function add_app_admin(p_email text, p_note text default null)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_count int;
  v_rows int;
begin
  select count(*), min(id::text)::uuid into v_count, v_id from alumni_profiles
   where lower(email) = lower(btrim(p_email)) and deleted_at is null;
  if v_count = 0 then
    raise exception 'no_profile_with_email';
  elsif v_count > 1 then
    raise exception 'more_than_one_profile_with_email';
  end if;
  insert into app_admins (profile_id, note) values (v_id, p_note)
    on conflict (profile_id) do nothing;
  get diagnostics v_rows = row_count;
  return case when v_rows = 1 then 'added' else 'already_admin' end;
end;
$$;

create or replace function remove_app_admin(p_email text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_rows int;
begin
  delete from app_admins
   where profile_id in (select id from alumni_profiles
                         where lower(email) = lower(btrim(p_email))
                           and deleted_at is null);
  get diagnostics v_rows = row_count;
  return case when v_rows > 0 then 'removed' else 'not_admin' end;
end;
$$;

create or replace function list_app_admins()
returns table (name text, email text, note text, added_at timestamptz)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.name, p.email, a.note, a.added_at
    from app_admins a join alumni_profiles p on p.id = a.profile_id
   order by a.added_at;
$$;

revoke execute on function add_app_admin(text, text) from public, anon, authenticated, service_role;
revoke execute on function remove_app_admin(text) from public, anon, authenticated, service_role;
revoke execute on function list_app_admins() from public, anon, authenticated, service_role;
