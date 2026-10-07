-- ============================================================================
-- Default contact to share (7 Oct 2026).
--
-- A person can save one default contact (any text: WhatsApp, email, Instagram,
-- Telegram, phone, up to 200 characters). It only pre-fills the "what do you
-- want to share" box when they accept a contact request. It is never shared
-- by itself: the person still confirms it on every accept.
--
-- It lives in its OWN table, not on alumni_profiles, because the Directory
-- reads alumni_profiles. The table has no access for anon / authenticated;
-- only the two functions below (SECURITY DEFINER) can read or write it.
-- The row is removed when an account is deleted.
--
-- HONEST LIMIT: like the other functions, the profile id sent by the app is
-- not authenticated (see docs/DECISIONS.md).
--
-- Idempotent. Rollback: supabase/rollback_default_share_contact.sql
-- ============================================================================

create table if not exists profile_share_defaults (
  profile_id uuid primary key references alumni_profiles (id) on delete cascade,
  contact text not null check (char_length(btrim(contact)) between 1 and 200),
  updated_at timestamptz not null default now()
);
alter table profile_share_defaults enable row level security;
revoke all on profile_share_defaults from public, anon, authenticated;

create or replace function contact_default_get(p_profile uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select contact from profile_share_defaults where profile_id = p_profile;
$$;

-- Empty text clears the default.
create or replace function contact_default_set(p_profile uuid, p_contact text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v text := nullif(btrim(coalesce(p_contact, '')), '');
begin
  if not business_is_verified(p_profile) then raise exception 'not_verified'; end if;
  if char_length(coalesce(v, '')) > 200 then raise exception 'shared_too_long'; end if;
  if v is null then
    delete from profile_share_defaults where profile_id = p_profile;
  else
    insert into profile_share_defaults (profile_id, contact) values (p_profile, v)
    on conflict (profile_id) do update set contact = excluded.contact, updated_at = now();
  end if;
end;
$$;

revoke execute on function contact_default_get(uuid) from public;
revoke execute on function contact_default_set(uuid, text) from public;
grant execute on function contact_default_get(uuid) to anon, authenticated;
grant execute on function contact_default_set(uuid, text) to anon, authenticated;

-- Deleting an account (deleted_at set) also removes the saved contact.
create or replace function profile_share_defaults_cleanup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from profile_share_defaults where profile_id = new.id;
  return new;
end;
$$;
revoke execute on function profile_share_defaults_cleanup() from public, anon, authenticated;

create or replace trigger profile_share_defaults_cleanup_trigger
  after update of deleted_at on alumni_profiles
  for each row
  when (new.deleted_at is not null and old.deleted_at is null)
  execute function profile_share_defaults_cleanup();
