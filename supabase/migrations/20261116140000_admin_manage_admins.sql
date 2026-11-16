-- In-app admin management: list, add and remove admins.
--
-- Rules, all checked here in the database:
--   * only an admin can list, add or remove admins (app_admin_assert);
--   * the real sign in must be on (require_login): with it off the admin id
--     is only a parameter, so these functions refuse ('login_required');
--   * a new admin must be an active, verified member (not deleted, not
--     suspended);
--   * an admin cannot remove themself ('cannot_remove_self');
--   * the last admin can never be removed ('last_admin');
--   * an owner admin (app_admins.is_owner) can only be removed from the
--     Supabase dashboard ('owner_protected'). Farrel's profile is the owner.
-- Each add and remove writes a Riwayat row (admin_actions) in the same
-- transaction, so the log cannot be skipped.
-- The dashboard (service role / postgres) still edits app_admins directly.
-- Idempotent. Rollback: supabase/rollback_admin_manage_admins.sql

alter table app_admins add column if not exists is_owner boolean not null default false;
update app_admins set is_owner = true
 where profile_id = 'b94b209e-4174-4c42-b92e-5757f8df64ca' and not is_owner;

create or replace function admin_admins_list(p_admin uuid)
returns table (
  profile_id uuid, name text, email text, major text, graduation_year integer,
  is_owner boolean, note text, added_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not login_required() then raise exception 'login_required'; end if;
  perform app_admin_assert(p_admin);
  return query
    select a.profile_id, p.name, p.email, p.major, p.graduation_year,
           a.is_owner, a.note, a.added_at
      from app_admins a
      join alumni_profiles p on p.id = a.profile_id
     order by a.is_owner desc, a.added_at, p.name;
end;
$$;

create or replace function admin_admin_add(p_admin uuid, p_profile uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if not login_required() then raise exception 'login_required'; end if;
  perform app_admin_assert(p_admin);
  select name into v_name from alumni_profiles
   where id = p_profile and deleted_at is null;
  if not found then raise exception 'not_found'; end if;
  if exists (select 1 from alumni_profiles where id = p_profile
              and (suspended_at is not null or verification_status <> 'verified')) then
    raise exception 'invalid_state';
  end if;
  insert into app_admins (profile_id, note)
    values (p_profile, 'Ditambah di aplikasi')
    on conflict (profile_id) do nothing;
  if not found then raise exception 'already_admin'; end if;
  insert into admin_actions (admin_id, action, target_type, target_id, detail)
    values (p_admin, 'admin_add', 'profile', p_profile::text, left(v_name, 300));
end;
$$;

create or replace function admin_admin_remove(p_admin uuid, p_profile uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner boolean;
  v_name text;
begin
  if not login_required() then raise exception 'login_required'; end if;
  perform app_admin_assert(p_admin);
  -- Lock the admin rows so two removals at once cannot leave zero admins.
  perform 1 from app_admins for update;
  select a.is_owner, p.name into v_owner, v_name
    from app_admins a left join alumni_profiles p on p.id = a.profile_id
   where a.profile_id = p_profile;
  if not found then raise exception 'not_found'; end if;
  if p_profile = p_admin then raise exception 'cannot_remove_self'; end if;
  if (select count(*) from app_admins) <= 1 then raise exception 'last_admin'; end if;
  if v_owner then raise exception 'owner_protected'; end if;
  delete from app_admins where profile_id = p_profile;
  insert into admin_actions (admin_id, action, target_type, target_id, detail)
    values (p_admin, 'admin_remove', 'profile', p_profile::text, left(v_name, 300));
end;
$$;

revoke execute on function admin_admins_list(uuid) from public;
revoke execute on function admin_admin_add(uuid, uuid) from public;
revoke execute on function admin_admin_remove(uuid, uuid) from public;
grant execute on function admin_admins_list(uuid) to anon, authenticated;
grant execute on function admin_admin_add(uuid, uuid) to anon, authenticated;
grant execute on function admin_admin_remove(uuid, uuid) to anon, authenticated;
