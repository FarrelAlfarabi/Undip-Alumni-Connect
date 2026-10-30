-- Review fixes for the redesign migrations (30 Oct 2026). Needs
-- 20261030160000_categories.sql and 20261030170000_profile_avatar.sql first.
--
-- 1. category_must_be_active() was security definer, so current_user was
--    always the owner and every caller skipped the check: a hidden category
--    could still be chosen for a product. It now runs as the caller and tells
--    an API request (PostgREST sets request.jwt.claims) from the dashboard.
--    Farrel can still set any category in the dashboard.
-- 2. The avatars bucket had a select policy, so anyone could list every
--    photo and the profile ids in the folder names. A public bucket serves
--    files by link without one (same as job-photos).
-- 3. The photo link CHECK now also ties the link to the row's own folder and
--    ends at the file name, so a link to another person's photo cannot be
--    written straight to the table either.
--
-- Idempotent. Rollback: supabase/rollback_review_security_fixes.sql
-- Not applied to the live project by this change.

create or replace function category_must_be_active()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_claims text := nullif(current_setting('request.jwt.claims', true), '');
begin
  if v_claims is null then
    -- Not an API request: the dashboard or a migration may set any value.
    if current_user in ('postgres', 'supabase_admin', 'service_role') then
      return new;
    end if;
  elsif (v_claims::jsonb ->> 'role') = 'service_role' then
    return new;
  end if;
  if tg_op = 'INSERT' or new.category is distinct from old.category then
    if not exists (select 1 from categories where name = new.category and active) then
      raise exception 'invalid_category' using errcode = '23514';
    end if;
  end if;
  return new;
end $$;

revoke execute on function category_must_be_active() from public, anon, authenticated;

drop policy if exists "avatars_public_read" on storage.objects;

alter table alumni_profiles drop constraint if exists alumni_profiles_avatar_url_check;
alter table alumni_profiles add constraint alumni_profiles_avatar_url_check
  check (
    avatar_url is null
    or (char_length(avatar_url) <= 500
        and avatar_url ~ ('^https://[^/]+/storage/v1/object/public/avatars/'
                          || id::text || '/[^?#/]+$'))
  );
