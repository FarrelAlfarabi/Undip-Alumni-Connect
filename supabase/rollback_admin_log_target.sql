-- Rollback of 20261117100000_admin_log_target.
-- Restores admin_member_remove (no label) and the old admin_actions_search.
drop trigger if exists trg_admin_actions_fill_label on admin_actions;
drop function if exists admin_actions_fill_label();

create or replace function admin_member_remove(p_admin uuid, p_profile uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_result jsonb;
begin
  if not login_required() then raise exception 'login_required'; end if;
  perform app_admin_assert(p_admin);
  if v_reason is null then raise exception 'reason_required'; end if;
  if p_profile is null or p_profile = p_admin then raise exception 'cannot_remove_self'; end if;
  perform 1 from alumni_profiles where id = p_profile and deleted_at is null;
  if not found then raise exception 'not_found'; end if;
  if exists (select 1 from app_admins where profile_id = p_profile) then
    raise exception 'target_is_admin';
  end if;
  v_result := account_delete_core(p_profile);
  insert into admin_actions (admin_id, action, target_type, target_id, detail)
    values (p_admin, 'member_remove', 'profile', p_profile::text, left(v_reason, 300));
  return v_result - 'files';
end;
$$;

drop function if exists admin_actions_search(uuid, text, text, uuid, timestamptz, integer);
create or replace function admin_actions_search(
  p_admin uuid, p_search text default null, p_action_prefix text default null,
  p_admin_filter uuid default null, p_since timestamptz default null, p_limit integer default 200
)
returns table (
  id uuid, admin_id uuid, admin_name text, action text, target_type text,
  target_id text, detail text, created_at timestamptz
)
language plpgsql stable security definer set search_path = public
as $$
declare
  v_q text := nullif(btrim(coalesce(p_search, '')), '');
  v_prefix text := nullif(btrim(coalesce(p_action_prefix, '')), '');
  v_pat text; v_prefix_pat text;
begin
  perform app_admin_assert(p_admin);
  if v_q is not null then
    v_pat := '%' || replace(replace(replace(left(v_q, 100), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  if v_prefix is not null then
    v_prefix_pat := replace(replace(replace(left(v_prefix, 60), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  return query
    select a.id, a.admin_id, p.name, a.action, a.target_type, a.target_id, a.detail, a.created_at
      from admin_actions a left join alumni_profiles p on p.id = a.admin_id
     where (v_pat is null or a.action ilike v_pat or a.target_type ilike v_pat
            or a.target_id ilike v_pat or a.detail ilike v_pat or p.name ilike v_pat)
       and (v_prefix_pat is null or a.action like v_prefix_pat)
       and (p_admin_filter is null or a.admin_id = p_admin_filter)
       and (p_since is null or a.created_at >= p_since)
     order by a.created_at desc
     limit least(greatest(coalesce(p_limit, 200), 1), 500);
end;
$$;
revoke execute on function admin_actions_search(uuid, text, text, uuid, timestamptz, integer) from public;
grant execute on function admin_actions_search(uuid, text, text, uuid, timestamptz, integer) to anon, authenticated;

alter table admin_actions drop column if exists target_label;
