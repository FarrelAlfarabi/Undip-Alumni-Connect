-- Admin member list: read every member, not only the first 1000.
--
-- Bug found 26 Nov 2026: admin_members_list stopped at 1000 rows (a to about M
-- by name), but the demo project has 1885 members, so the rest could not be
-- found, edited or suspended in the app. Now it takes p_offset and returns 500
-- rows per call; the app asks again until a page comes back short.
-- Old builds that call it with two arguments still work (p_offset defaults to 0
-- and they see the first 500, so update the app with this change).
-- Same checks as before: admin only (assert_caller + app_admin_assert).
-- Idempotent. Rollback: supabase/rollback_admin_members_list_paging.sql

drop function if exists admin_members_list(uuid, text);

create or replace function admin_members_list(
  p_admin uuid, p_search text default null, p_offset integer default 0
)
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
     order by p.name, p.id
     limit 500 offset greatest(coalesce(p_offset, 0), 0);
end;
$$;
revoke execute on function admin_members_list(uuid, text, integer) from public;
grant execute on function admin_members_list(uuid, text, integer) to anon, authenticated;
