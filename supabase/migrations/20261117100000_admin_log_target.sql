-- Riwayat: say who the action was done to.
--
-- Before: a Riwayat row held only the admin, the action and a free detail.
-- "Anggota dihapus" kept the member's id and reason, and the name was erased
-- with the account, so nobody could later answer "who did we delete?".
--
--   * admin_actions.target_label: a short "Name (email)" or title of the thing
--     the action was done to, saved when the row is written;
--   * a trigger fills target_label for profile, business and job targets
--     when the writer did not give one (the row still exists at that time);
--   * admin_member_remove saves the label BEFORE the account is erased;
--   * old rows about members who still exist get their label now. Rows about
--     members already deleted cannot be recovered (the name is gone);
--   * admin_actions_search returns target_label and searches it too.
-- Idempotent. Rollback: supabase/rollback_admin_log_target.sql

alter table admin_actions add column if not exists target_label text
  check (target_label is null or char_length(target_label) <= 200);

create or replace function admin_actions_fill_label()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.target_label is null and new.target_id is not null then
    begin
      if new.target_type = 'profile' then
        select left(concat_ws(' ', nullif(name, ''), '(' || email || ')'), 200)
          into new.target_label
          from alumni_profiles where id = new.target_id::uuid and deleted_at is null;
      elsif new.target_type = 'business' then
        select left(name, 200) into new.target_label
          from businesses where id = new.target_id::uuid;
      elsif new.target_type = 'job' then
        select left(title, 200) into new.target_label
          from job_posts where id = new.target_id::uuid;
      end if;
    exception when invalid_text_representation then
      new.target_label := null;
    end;
  end if;
  return new;
end;
$$;
revoke execute on function admin_actions_fill_label() from public, anon, authenticated;

drop trigger if exists trg_admin_actions_fill_label on admin_actions;
create trigger trg_admin_actions_fill_label
  before insert on admin_actions
  for each row execute function admin_actions_fill_label();

-- Old rows: only where the target still exists with its real name.
update admin_actions a
   set target_label = left(concat_ws(' ', nullif(p.name, ''), '(' || p.email || ')'), 200)
  from alumni_profiles p
 where a.target_type = 'profile'
   and a.target_label is null
   and a.target_id ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
   and p.id = a.target_id::uuid
   and p.deleted_at is null;

create or replace function admin_member_remove(p_admin uuid, p_profile uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_label text;
  v_result jsonb;
begin
  if not login_required() then raise exception 'login_required'; end if;
  perform app_admin_assert(p_admin);
  if v_reason is null then raise exception 'reason_required'; end if;
  if p_profile is null or p_profile = p_admin then raise exception 'cannot_remove_self'; end if;
  select left(concat_ws(' ', nullif(name, ''), '(' || email || ')'), 200) into v_label
    from alumni_profiles where id = p_profile and deleted_at is null;
  if not found then raise exception 'not_found'; end if;
  if exists (select 1 from app_admins where profile_id = p_profile) then
    raise exception 'target_is_admin';
  end if;
  v_result := account_delete_core(p_profile);
  insert into admin_actions (admin_id, action, target_type, target_id, target_label, detail)
    values (p_admin, 'member_remove', 'profile', p_profile::text, v_label,
            left(v_reason, 300));
  return v_result - 'files';
end;
$$;
revoke execute on function admin_member_remove(uuid, uuid, text) from public;
grant execute on function admin_member_remove(uuid, uuid, text) to anon, authenticated;

drop function if exists admin_actions_search(uuid, text, text, uuid, timestamptz, integer);
create or replace function admin_actions_search(
  p_admin uuid,
  p_search text default null,
  p_action_prefix text default null,
  p_admin_filter uuid default null,
  p_since timestamptz default null,
  p_limit integer default 200
)
returns table (
  id uuid, admin_id uuid, admin_name text, action text, target_type text,
  target_id text, target_label text, detail text, created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_q text := nullif(btrim(coalesce(p_search, '')), '');
  v_prefix text := nullif(btrim(coalesce(p_action_prefix, '')), '');
  v_pat text;
  v_prefix_pat text;
begin
  perform app_admin_assert(p_admin);
  if v_q is not null then
    v_pat := '%' || replace(replace(replace(left(v_q, 100), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  if v_prefix is not null then
    v_prefix_pat := replace(replace(replace(left(v_prefix, 60), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  return query
    select a.id, a.admin_id, p.name, a.action, a.target_type, a.target_id,
           a.target_label, a.detail, a.created_at
      from admin_actions a
      left join alumni_profiles p on p.id = a.admin_id
     where (v_pat is null
            or a.action ilike v_pat or a.target_type ilike v_pat
            or a.target_id ilike v_pat or a.target_label ilike v_pat
            or a.detail ilike v_pat or p.name ilike v_pat)
       and (v_prefix_pat is null or a.action like v_prefix_pat)
       and (p_admin_filter is null or a.admin_id = p_admin_filter)
       and (p_since is null or a.created_at >= p_since)
     order by a.created_at desc
     limit least(greatest(coalesce(p_limit, 200), 1), 500);
end;
$$;
revoke execute on function admin_actions_search(uuid, text, text, uuid, timestamptz, integer) from public;
grant execute on function admin_actions_search(uuid, text, text, uuid, timestamptz, integer) to anon, authenticated;
