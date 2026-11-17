-- Admin can change a member's name and email (17 Nov 2026).
--
-- admin_update_profile accepts two more keys: name (2 to 100 characters) and
-- email (valid address, saved in lower case).
--   * email taken by another member -> 'email_taken'; nothing is saved;
--   * an email change needs the real sign in on ('login_required'): with it off
--     the admin id is only a parameter and anyone could take over an account;
--   * the email of any admin (own or another) is not changed here
--     ('cannot_change_admin_email'): a typo would lock an admin out. Remove the
--     admin in Kelola admin first, change the email, add them again;
--   * (old) an admin cannot change their OWN email here ('cannot_change_own_email'):
--     a typo would lock them out (edit it in the Supabase dashboard);
--   * when the email really changes, alumni_profiles.user_id is cleared. The
--     old sign in no longer matches the profile, so the member signs in once
--     with the NEW email (email code) and the profile links to that sign in.
--     The old email can no longer get a code (login_email_known is false).
--   * Riwayat keeps "nama: old -> new" and "email: old -> new" in the detail
--     (the identity change must be traceable); other fields stay names only.
-- Email stays the only unique member key (alumni_profiles_email_key).
-- Farrel can still edit any row in the Supabase dashboard.
-- Idempotent. Rollback: supabase/rollback_admin_edit_name_email.sql

create or replace function admin_update_profile(
  p_admin uuid, p_profile uuid, p_changes jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_allowed constant text[] := array['current_role','industry','company','city','bio','linkedin_url','name','email'];
  v_key text;
  v_val jsonb;
  v_text text;
  v_role text; v_industry text; v_company text; v_city text; v_bio text; v_link text;
  v_name text; v_email text;
  v_old_name text; v_old_email text;
  v_detail text;
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
    elsif v_key = 'name' then
      if v_text is null or char_length(v_text) not between 2 and 100
         or v_text ~ '[[:cntrl:]]' then
        raise exception 'invalid_input';
      end if;
      v_name := v_text;
    elsif v_key = 'email' then
      v_text := lower(v_text);
      if v_text is null or char_length(v_text) > 200
         or v_text !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
        raise exception 'invalid_input';
      end if;
      v_email := v_text;
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

  select name, email into v_old_name, v_old_email
    from alumni_profiles where id = p_profile and deleted_at is null;
  if not found then raise exception 'not_found'; end if;

  if p_changes ? 'email' and lower(v_old_email) is distinct from v_email then
    -- Your own login email is not changed here: a typo would lock you out.
    if not login_required() then raise exception 'login_required'; end if;
    if p_profile = p_admin then raise exception 'cannot_change_own_email'; end if;
    if exists (select 1 from app_admins where profile_id = p_profile) then
      raise exception 'cannot_change_admin_email';
    end if;
    if exists (select 1 from alumni_profiles
                where lower(email) = v_email and id <> p_profile) then
      raise exception 'email_taken';
    end if;
  end if;

  begin
  update alumni_profiles set
    name             = case when p_changes ? 'name' then v_name else name end,
    email            = case when p_changes ? 'email' then v_email else email end,
    -- A new email is a new login: the old sign in is detached and the member
    -- signs in once with the new email (email code), which links it again.
    user_id          = case when p_changes ? 'email' and lower(v_old_email) is distinct from v_email
                            then null else user_id end,
    "current_role"   = case when p_changes ? 'current_role' then v_role else "current_role" end,
    industry         = case when p_changes ? 'industry' then v_industry else industry end,
    company          = case when p_changes ? 'company' then v_company else company end,
    current_employer = case when p_changes ? 'company' then v_company else current_employer end,
    city             = case when p_changes ? 'city' then v_city else city end,
    bio              = case when p_changes ? 'bio' then v_bio else bio end,
    linkedin_url     = case when p_changes ? 'linkedin_url' then v_link else linkedin_url end,
    updated_at       = now()
  where id = p_profile and deleted_at is null;
  exception when unique_violation then raise exception 'email_taken';
  end;
  if not found then raise exception 'not_found'; end if;

  v_detail := left((select string_agg(k, ', ' order by k) from jsonb_object_keys(p_changes) k), 60);
  if p_changes ? 'name' and v_old_name is distinct from v_name then
    v_detail := v_detail || ' | nama: ' || v_old_name || ' -> ' || v_name;
  end if;
  if p_changes ? 'email' and lower(v_old_email) is distinct from v_email then
    v_detail := v_detail || ' | email: ' || v_old_email || ' -> ' || v_email;
  end if;
  perform admin_log_action(
    p_admin, 'edit_profile', 'profile', p_profile::text, left(v_detail, 300));
end;
$$;

revoke execute on function admin_update_profile(uuid, uuid, jsonb) from public;
grant execute on function admin_update_profile(uuid, uuid, jsonb) to anon, authenticated;

