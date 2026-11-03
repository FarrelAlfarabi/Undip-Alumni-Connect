-- ============================================================================
-- Real login, database side, re-applied. DORMANT: require_login stays 'off'.
--
-- Why this file exists: 20261013120000_real_login.sql was never run on the
-- live database, and the deploy repair marks it as applied. This file carries
-- the same SQL so it really runs, with two differences:
--   * current_profile_id() and claim_alumni_profile() are NOT redefined here.
--     20261018090000_suspend_user.sql has the newer versions that refuse a
--     suspended person. Redefining them would undo suspension.
--   * It runs last, so the assert_caller guard is added to the functions as
--     they are today (later migrations replaced some of them).
-- The switch (require_login = 'on') is NOT here. supabase/cutover_real_login.sql
-- does that by hand, only after the REAL_LOGIN=true build is live.
-- Idempotent. Rollback: supabase/rollback_real_login.sql
-- ============================================================================

create table if not exists app_settings (
  key   text primary key,
  value text not null
);
alter table app_settings enable row level security;
revoke all on app_settings from public, anon, authenticated;
insert into app_settings (key, value) values ('require_login', 'off')
  on conflict (key) do nothing;

alter table alumni_profiles add column if not exists user_id uuid;
create unique index if not exists alumni_profiles_user_id_key
  on alumni_profiles (user_id) where user_id is not null;

create or replace function login_required()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select value = 'on' from app_settings where key = 'require_login'), false);
$$;

create or replace function assert_caller(p_profile uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not login_required() then
    return;
  end if;
  if auth.uid() is null
     or p_profile is null
     or current_profile_id() is distinct from p_profile then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
end;
$$;

revoke execute on function login_required() from public;
revoke execute on function assert_caller(uuid) from public;
grant execute on function login_required() to anon, authenticated;
grant execute on function assert_caller(uuid) to anon, authenticated;

-- Admin check: unchanged while require_login is off.
create or replace function is_app_admin(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_profile is not null
     and exists (select 1 from app_admins where profile_id = p_profile)
     and (not login_required()
          or coalesce(p_profile = current_profile_id(), false));
$$;
revoke execute on function is_app_admin(uuid) from public;
grant execute on function is_app_admin(uuid) to anon, authenticated;

create or replace function login_email_known(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from alumni_profiles
     where lower(email) = lower(btrim(p_email))
       and deleted_at is null
       and verification_status <> 'failed'
  );
$$;
revoke execute on function login_email_known(text) from public;
grant execute on function login_email_known(text) to anon, authenticated;

-- Put assert_caller(<param>) first in every function that trusts an id sent
-- by the app. Safe to run again: a function that already has it is skipped.
do $$
declare
  t record;
  f record;
  v_def text;
  v_skipped text := '';
begin
  for t in
    select * from (values
      ('account_accept_policy', 'p_profile'), ('account_delete', 'p_profile'),
      ('account_files', 'p_profile'),
      ('business_directory', 'p_viewer'), ('business_my', 'p_owner'),
      ('business_my_usage', 'p_owner'), ('business_photo_urls', 'p_viewer'),
      ('business_register', 'p_owner'), ('business_set_photo', 'p_owner'),
      ('business_update', 'p_owner'),
      ('contact_default_get', 'p_profile'), ('contact_default_set', 'p_profile'),
      ('contact_request_respond', 'p_target'), ('contact_request_send', 'p_requester'),
      ('contact_request_shared_contact', 'p_requester'),
      ('contact_requests_incoming', 'p_target'), ('contact_requests_outgoing', 'p_requester'),
      ('contact_requests_pending_count', 'p_target'),
      ('content_report_create', 'p_reporter'), ('demo_subscribe', 'p_profile'),
      ('marketplace_create_listing', 'p_seller'), ('marketplace_delete_listing', 'p_seller'),
      ('marketplace_my_listings', 'p_seller'), ('marketplace_set_sold', 'p_seller'),
      ('marketplace_update_listing', 'p_seller'), ('marketplace_set_admin_key', 'p_profile'),
      ('notifications_list', 'p_recipient'), ('notifications_mark_read', 'p_recipient'),
      ('notifications_unread_count', 'p_recipient'),
      ('user_block', 'p_blocker'), ('user_blocks_list', 'p_blocker'),
      ('user_unblock', 'p_blocker')
    ) as x(fname, param)
  loop
    for f in
      select p.oid, l.lanname
        from pg_proc p
        join pg_language l on l.oid = p.prolang
       where p.pronamespace = 'public'::regnamespace and p.proname = t.fname
    loop
      v_def := pg_get_functiondef(f.oid);
      if v_def like '%assert_caller(%' then
        continue;
      end if;
      if f.lanname = 'plpgsql' then
        v_def := regexp_replace(
          v_def, '\mbegin\M', 'begin' || E'\n  perform assert_caller(' || t.param || ');', 'i');
      elsif f.lanname = 'sql' then
        -- A SQL function may have several statements; the last one is its
        -- result, so the guard goes first.
        v_def := regexp_replace(
          v_def, '(AS \$[a-z_]*\$)', '\1' || E'\n  select assert_caller(' || t.param || ');');
      else
        v_skipped := v_skipped || t.fname || ' ';
        continue;
      end if;
      execute v_def;
    end loop;
  end loop;
  if v_skipped <> '' then
    raise exception 'real_login: not plpgsql, cannot guard: %', v_skipped;
  end if;
end $$;
