-- Admin member list: suspend or unsuspend any member, and fix NIM or jurusan.
--
-- 1. admin_members_list: same as admin_members_search (kept for older
--    builds) plus verification_status, suspended_at, suspended_reason and
--    is_admin, so the list can show status and offer the right action.
--    Suspended members are listed (deleted ones are not).
-- 2. admin_member_set_suspended(p_admin, p_profile, p_suspend, p_reason):
--    the same suspension as Reports > "Block login", but from the member list.
--    A reason is required to suspend. Admins and yourself cannot be suspended
--    ('invalid_state'). Logged in Riwayat in the same transaction.
-- 3. admin_member_identity(p_admin, p_profile): NIM, faculty and jurusan of
--    one member, for the fix form only. NIM stays hidden everywhere else.
-- 4. admin_member_set_identity(p_admin, p_profile, p_nim, p_major): fixes a
--    wrong NIM or jurusan from the import. NIM: 5 to 30 letters, digits or dashes,
--    unique ('nim_taken'). Jurusan: 2 to 80 characters. The Riwayat row names
--    the fields, never the values.
-- All admin only (app_admin_assert). The dashboard still edits every row.
-- Idempotent. Rollback: supabase/rollback_admin_member_status.sql

create or replace function admin_members_list(p_admin uuid, p_search text default null)
returns table (
  id uuid, name text, email text, major text, graduation_year integer,
  "current_role" text, industry text, company text, city text,
  bio text, linkedin_url text,
  verification_status text, suspended_at timestamptz, suspended_reason text,
  is_admin boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_q text := nullif(btrim(coalesce(p_search, '')), '');
begin
  perform assert_caller(p_admin);
  perform app_admin_assert(p_admin);
  if v_q is not null then
    v_q := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  return query
    select p.id, p.name, p.email, p.major, p.graduation_year,
           p."current_role", p.industry, p.company, p.city, p.bio, p.linkedin_url,
           p.verification_status::text, p.suspended_at, p.suspended_reason,
           exists (select 1 from app_admins a where a.profile_id = p.id)
      from alumni_profiles p
     where p.deleted_at is null
       and (v_q is null or p.name ilike v_q or p.email ilike v_q)
     order by p.name
     limit 1000;
end;
$$;
revoke execute on function admin_members_list(uuid, text) from public;
grant execute on function admin_members_list(uuid, text) to anon, authenticated;

create or replace function admin_member_set_suspended(
  p_admin uuid, p_profile uuid, p_suspend boolean, p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_name text;
begin
  perform app_admin_assert(p_admin);
  if p_suspend is null then raise exception 'invalid_action'; end if;
  select name into v_name from alumni_profiles
   where id = p_profile and deleted_at is null for update;
  if not found then raise exception 'not_found'; end if;
  if p_profile = p_admin
     or exists (select 1 from app_admins where profile_id = p_profile) then
    raise exception 'invalid_state';
  end if;
  if p_suspend then
    if v_reason is null then raise exception 'reason_required'; end if;
    update alumni_profiles set suspended_at = now(), suspended_reason = left(v_reason, 300)
     where id = p_profile and suspended_at is null;
    if not found then raise exception 'invalid_state'; end if;
  else
    update alumni_profiles set suspended_at = null, suspended_reason = null
     where id = p_profile and suspended_at is not null;
    if not found then raise exception 'invalid_state'; end if;
  end if;
  insert into admin_actions (admin_id, action, target_type, target_id, detail)
    values (p_admin, case when p_suspend then 'member_suspend' else 'member_unsuspend' end,
            'profile', p_profile::text,
            left(v_name || coalesce(': ' || v_reason, ''), 300));
end;
$$;
revoke execute on function admin_member_set_suspended(uuid, uuid, boolean, text) from public;
grant execute on function admin_member_set_suspended(uuid, uuid, boolean, text) to anon, authenticated;

create or replace function admin_member_identity(p_admin uuid, p_profile uuid)
returns table (nim text, faculty text, major text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select p.nim, p.faculty, p.major from alumni_profiles p
     where p.id = p_profile and p.deleted_at is null;
  if not found then raise exception 'not_found'; end if;
end;
$$;
revoke execute on function admin_member_identity(uuid, uuid) from public;
grant execute on function admin_member_identity(uuid, uuid) to anon, authenticated;

create or replace function admin_member_set_identity(
  p_admin uuid, p_profile uuid, p_nim text, p_major text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nim text := nullif(upper(btrim(coalesce(p_nim, ''))), '');
  v_major text := nullif(btrim(coalesce(p_major, '')), '');
  v_old_nim text;
  v_old_major text;
  v_fields text[] := '{}';
begin
  perform app_admin_assert(p_admin);
  if v_nim is null or v_nim !~ '^[A-Z0-9-]{5,30}$' then raise exception 'invalid_input'; end if;
  if v_major is null or char_length(v_major) not between 2 and 80 then
    raise exception 'invalid_input';
  end if;
  select nim, major into v_old_nim, v_old_major from alumni_profiles
   where id = p_profile and deleted_at is null for update;
  if not found then raise exception 'not_found'; end if;
  if exists (select 1 from alumni_profiles
              where upper(btrim(nim)) = v_nim and id <> p_profile) then
    raise exception 'nim_taken';
  end if;
  if v_nim is distinct from v_old_nim then v_fields := array_append(v_fields, 'nim'); end if;
  if v_major is distinct from v_old_major then v_fields := array_append(v_fields, 'major'); end if;
  if cardinality(v_fields) = 0 then return; end if;
  begin
    update alumni_profiles set nim = v_nim, major = v_major, updated_at = now()
     where id = p_profile;
  exception when unique_violation then
    raise exception 'nim_taken';
  end;
  insert into admin_actions (admin_id, action, target_type, target_id, detail)
    values (p_admin, 'member_fix_identity', 'profile', p_profile::text,
            array_to_string(v_fields, ', '));
end;
$$;
revoke execute on function admin_member_set_identity(uuid, uuid, text, text) from public;
grant execute on function admin_member_set_identity(uuid, uuid, text, text) to anon, authenticated;
