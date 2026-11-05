-- Admin action log: who approved, rejected, hid, deleted what, and when.
-- The admin app writes one row after each admin action (admin_log_action);
-- only admins can write or read it. Rows are kept for the dashboard too.
-- Idempotent. Rollback: supabase/rollback_admin_action_log.sql
create table if not exists admin_actions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references alumni_profiles (id) on delete set null,
  action text not null check (char_length(action) between 1 and 60),
  target_type text check (target_type is null or char_length(target_type) <= 40),
  target_id text check (target_id is null or char_length(target_id) <= 80),
  detail text check (detail is null or char_length(detail) <= 300),
  created_at timestamptz not null default now()
);
create index if not exists idx_admin_actions_created on admin_actions (created_at desc);
alter table admin_actions enable row level security;
revoke all on admin_actions from public, anon, authenticated;

create or replace function admin_log_action(
  p_admin uuid, p_action text, p_target_type text default null,
  p_target_id text default null, p_detail text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  insert into admin_actions (admin_id, action, target_type, target_id, detail)
    values (p_admin, left(btrim(p_action), 60), left(p_target_type, 40),
            left(p_target_id, 80), left(p_detail, 300));
end;
$$;

create or replace function admin_actions_list(p_admin uuid)
returns table (
  id uuid, admin_name text, action text, target_type text, target_id text,
  detail text, created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select a.id, p.name, a.action, a.target_type, a.target_id, a.detail, a.created_at
      from admin_actions a
      left join alumni_profiles p on p.id = a.admin_id
     order by a.created_at desc
     limit 200;
end;
$$;

revoke execute on function admin_log_action(uuid, text, text, text, text) from public;
revoke execute on function admin_actions_list(uuid) from public;
grant execute on function admin_log_action(uuid, text, text, text, text) to anon, authenticated;
grant execute on function admin_actions_list(uuid) to anon, authenticated;
