-- Rollback of 20261126140000_admin_members_list_paging: back to the first 1000
-- members only. Roll the app back first (it sends p_offset).
drop function if exists admin_members_list(uuid, text, integer);

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
