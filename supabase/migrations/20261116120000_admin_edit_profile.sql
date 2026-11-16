-- Admin "Ubah profil anggota" (16 Nov 2026): an admin edits the same basic
-- fields a member can edit in their own profile, nothing more.
--
--   Allowed keys: current_role, industry, company, city, bio, linkedin_url.
--   Anything else (nim, email, name, faculty, major, graduation_year,
--   verification_status, subscription_status, user_id, ...) is refused with
--   'protected_field' and nothing is saved.
--
-- Only sent keys change. Blank clears the value. company also sets
-- current_employer (the app keeps both equal). Every edit is written to the
-- admin log (admin_actions) with the field names only, never the values.
-- The photo is not covered: it needs a file upload under the member's folder.
--
-- Farrel can still edit any row in the Supabase dashboard.
-- Idempotent. Rollback: supabase/rollback_admin_edit_profile.sql

create or replace function admin_update_profile(
  p_admin uuid, p_profile uuid, p_changes jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_allowed constant text[] := array['current_role','industry','company','city','bio','linkedin_url'];
  v_key text;
  v_val jsonb;
  v_text text;
  v_role text; v_industry text; v_company text; v_city text; v_bio text; v_link text;
begin
  perform assert_caller(p_admin);
  perform app_admin_assert(p_admin);
  if p_changes is null or jsonb_typeof(p_changes) <> 'object' or p_changes = '{}'::jsonb then
    raise exception 'invalid_input';
  end if;

  -- Protected fields first, so a mixed request saves nothing.
  for v_key in select jsonb_object_keys(p_changes) loop
    if not (v_key = any (v_allowed)) then raise exception 'protected_field'; end if;
  end loop;

  for v_key, v_val in select * from jsonb_each(p_changes) loop
    if jsonb_typeof(v_val) not in ('string', 'null') then raise exception 'invalid_input'; end if;
    v_text := nullif(btrim(coalesce(v_val #>> '{}', '')), '');
    if v_key = 'current_role' then
      if char_length(coalesce(v_text, '')) > 120 then raise exception 'invalid_input'; end if;
      v_role := v_text;
    elsif v_key = 'industry' then
      if char_length(coalesce(v_text, '')) > 80 then raise exception 'invalid_input'; end if;
      v_industry := v_text;
    elsif v_key = 'company' then
      if char_length(coalesce(v_text, '')) > 120 then raise exception 'invalid_input'; end if;
      v_company := v_text;
    elsif v_key = 'city' then
      if char_length(coalesce(v_text, '')) > 80 then raise exception 'invalid_input'; end if;
      v_city := v_text;
    elsif v_key = 'bio' then
      if char_length(coalesce(v_text, '')) > 200 then raise exception 'invalid_input'; end if;
      v_bio := v_text;
    else
      if v_text is not null then
        if v_text !~* '^[a-z][a-z0-9+.-]*:' then v_text := 'https://' || v_text; end if;
        if char_length(v_text) > 200
           or v_text !~* '^https://([a-z0-9-]+\.)*linkedin\.com/[^[:space:]<>]*$' then
          raise exception 'invalid_input';
        end if;
      end if;
      v_link := v_text;
    end if;
  end loop;

  update alumni_profiles set
    "current_role"   = case when p_changes ? 'current_role' then v_role else "current_role" end,
    industry         = case when p_changes ? 'industry' then v_industry else industry end,
    company          = case when p_changes ? 'company' then v_company else company end,
    current_employer = case when p_changes ? 'company' then v_company else current_employer end,
    city             = case when p_changes ? 'city' then v_city else city end,
    bio              = case when p_changes ? 'bio' then v_bio else bio end,
    linkedin_url     = case when p_changes ? 'linkedin_url' then v_link else linkedin_url end,
    updated_at       = now()
  where id = p_profile and deleted_at is null;
  if not found then raise exception 'not_found'; end if;

  perform admin_log_action(
    p_admin, 'edit_profile', 'profile', p_profile::text,
    (select string_agg(k, ', ' order by k) from jsonb_object_keys(p_changes) k));
end;
$$;

revoke execute on function admin_update_profile(uuid, uuid, jsonb) from public;
grant execute on function admin_update_profile(uuid, uuid, jsonb) to anon, authenticated;

-- Find a member to edit: by name or email, 1000 rows at most (the app filters them on screen), never NIM.
create or replace function admin_members_search(p_admin uuid, p_search text default null)
returns table (
  id uuid, name text, email text, major text, graduation_year integer,
  "current_role" text, industry text, company text, city text,
  bio text, linkedin_url text
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
           p."current_role", p.industry, p.company, p.city, p.bio, p.linkedin_url
      from alumni_profiles p
     where p.deleted_at is null
       and (v_q is null or p.name ilike v_q or p.email ilike v_q)
     order by p.name
     limit 1000;
end;
$$;

revoke execute on function admin_members_search(uuid, text) from public;
grant execute on function admin_members_search(uuid, text) to anon, authenticated;
