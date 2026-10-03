-- ============================================================================
-- Email + password login, first password = the alumnus's NIM (2 Oct 2026).
--
-- * provision_alumni_accounts() creates a Supabase Auth account for every
--   alumni_profiles row that has an email and NIM but no account yet. The
--   password is the NIM and the email is marked confirmed (no email is sent).
--   It is idempotent: run it again after adding alumni.
--       select provision_alumni_accounts();
-- * alumni_profiles.password_set stays false until the person picks their own
--   password. The app makes them change it right after the first sign-in.
--   mark_password_set() flips it for the signed-in person only.
-- * claim_alumni_profile() (earlier migration) links the signed-in account to
--   the alumni row by email and now also returns password_set.
--
-- SECURITY: a NIM is not secret (alumni_profiles is readable with the app's
-- public key, and the seeds list NIMs). Until someone has chosen their own
-- password, anyone who knows their email and NIM can sign in as them, and
-- could change the password and lock the owner out. Acceptable only for demo
-- data. Real fix: send each person a set-password link instead.
--
-- Writes to the auth schema directly (there is no admin API from SQL).
-- Rollback: delete the auth.users rows whose email is in alumni_profiles and
-- drop the two functions and the column.
-- ============================================================================

alter table alumni_profiles add column if not exists password_set boolean not null default false;

create or replace function provision_alumni_accounts()
returns integer
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  r record;
  v_id uuid;
  v_count integer := 0;
begin
  for r in
    select email, nim from alumni_profiles
    where email is not null and nim is not null
      and not exists (select 1 from auth.users u where lower(u.email) = lower(alumni_profiles.email))
  loop
    v_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
      lower(r.email), crypt(r.nim, gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}', now(), now(),
      '', '', '', ''
    );
    insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
    values (
      gen_random_uuid(), v_id, v_id::text, 'email',
      jsonb_build_object('sub', v_id::text, 'email', lower(r.email), 'email_verified', true, 'phone_verified', false),
      now(), now(), now()
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke execute on function provision_alumni_accounts() from public, anon, authenticated;

create or replace function mark_password_set()
returns void
language sql
security definer
set search_path = public
as $$
  update alumni_profiles set password_set = true where user_id = auth.uid();
$$;
revoke execute on function mark_password_set() from public, anon;
grant execute on function mark_password_set() to authenticated;
