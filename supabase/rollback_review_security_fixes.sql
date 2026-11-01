-- Undo 20261030210000_review_security_fixes.sql: back to what
-- 20261030160000_categories.sql and 20261030170000_profile_avatar.sql made.
-- Safe to run twice.

create or replace function category_must_be_active()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- The dashboard (postgres / service role) may always set any value.
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
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
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

alter table alumni_profiles drop constraint if exists alumni_profiles_avatar_url_check;
alter table alumni_profiles add constraint alumni_profiles_avatar_url_check
  check (
    avatar_url is null
    or (char_length(avatar_url) <= 500
        and avatar_url ~ '^https://[^/]+/storage/v1/object/public/avatars/[^?#]+')
  );
