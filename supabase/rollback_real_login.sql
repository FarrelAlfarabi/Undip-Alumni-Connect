-- Rollback for 20261013120000_real_login.sql. Safe to run twice.
-- Removes the assert_caller line from every function it was added to, puts
-- back the original is_app_admin and claim_alumni_profile, then drops the new
-- helpers. alumni_profiles.user_id stays (it came from an older migration).
do $$
declare
  f record;
  v_def text;
begin
  for f in
    select p.oid
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname <> 'assert_caller'
       and pg_get_functiondef(p.oid) like '%assert_caller(%'
  loop
    v_def := regexp_replace(pg_get_functiondef(f.oid),
      E'\n  (perform|select) assert_caller\\([a-z_]+\\);', '', 'g');
    execute v_def;
  end loop;
end $$;

create or replace function is_app_admin(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_profile is not null
     and exists (select 1 from app_admins where profile_id = p_profile);
$$;

create or replace function claim_alumni_profile()
returns alumni_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_row alumni_profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select email into v_email from auth.users where id = v_uid;
  if v_email is null then
    raise exception 'No authenticated email found for this session';
  end if;

  select * into v_row
  from alumni_profiles
  where lower(email) = lower(v_email)
    and (user_id is null or user_id = v_uid)
  order by (user_id = v_uid) desc
  limit 1;

  if not found then
    raise exception 'No matching alumni record for this email';
  end if;

  if v_row.user_id is null then
    update alumni_profiles
    set user_id = v_uid,
        verification_status = 'verified'
    where id = v_row.id
    returning * into v_row;
  end if;

  return v_row;
end;
$$;

drop function if exists login_email_known(text);
drop function if exists assert_caller(uuid);
drop function if exists current_profile_id();
drop function if exists login_required();
drop index if exists alumni_profiles_user_id_key;
drop table if exists app_settings;
