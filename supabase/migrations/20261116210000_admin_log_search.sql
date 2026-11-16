-- Riwayat search and filters.
--
-- admin_actions_search(p_admin, p_search, p_action_prefix, p_admin_filter,
--                      p_since, p_limit)
--   * admin only (app_admin_assert);
--   * p_search matches the action, target type, target id, detail and the
--     admin's name (case does not matter);
--   * p_action_prefix keeps actions that start with it ('business_', 'job_',
--     'member_', 'admin_' ...);
--   * p_admin_filter keeps one admin's actions;
--   * p_since keeps actions from that time on;
--   * p_limit is capped at 500 (default 200).
-- admin_actions_list stays as it was for older app builds.
-- Idempotent. Rollback: supabase/rollback_admin_log_search.sql

create index if not exists idx_admin_actions_admin on admin_actions (admin_id, created_at desc);

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
  target_id text, detail text, created_at timestamptz
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
  -- Escape LIKE wildcards so the search text is matched literally.
  if v_q is not null then
    v_pat := '%' || replace(replace(replace(left(v_q, 100), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  if v_prefix is not null then
    v_prefix_pat := replace(replace(replace(left(v_prefix, 60), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  return query
    select a.id, a.admin_id, p.name, a.action, a.target_type, a.target_id,
           a.detail, a.created_at
      from admin_actions a
      left join alumni_profiles p on p.id = a.admin_id
     where (v_pat is null
            or a.action ilike v_pat or a.target_type ilike v_pat
            or a.target_id ilike v_pat or a.detail ilike v_pat
            or p.name ilike v_pat)
       and (v_prefix_pat is null or a.action like v_prefix_pat)
       and (p_admin_filter is null or a.admin_id = p_admin_filter)
       and (p_since is null or a.created_at >= p_since)
     order by a.created_at desc
     limit least(greatest(coalesce(p_limit, 200), 1), 500);
end;
$$;

revoke execute on function admin_actions_search(uuid, text, text, uuid, timestamptz, integer) from public;
grant execute on function admin_actions_search(uuid, text, text, uuid, timestamptz, integer) to anon, authenticated;
