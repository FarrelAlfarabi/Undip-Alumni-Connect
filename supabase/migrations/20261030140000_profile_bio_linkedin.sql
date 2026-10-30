-- Stage 4 (30 Oct 2026): a short Bio and an optional LinkedIn link on the
-- alumni profile, shown to other alumni on the member card and detail.
--
--   * alumni_profiles.bio: free text, at most 200 characters, null = none.
--   * alumni_profiles.linkedin_url: a linkedin.com link, at most 200
--     characters, null = none. The app adds https:// when it is missing.
--   * Both have the same select grant as the other profile columns
--     (20261018120000 and supabase/checks/live_db_checks.sql require it) and
--     the app names them in lib/data/profile_columns.dart.
--   * Members change their own two columns through the existing update policy
--     (alumni_profiles_update). alumni_profiles_restrict_update only blocks the
--     columns it lists, so it needs no change.
--   * Farrel can still see and edit both in the Supabase dashboard.
--   * Account deletion: account_delete() (20261003170000) clears personal
--     columns by name, so a small trigger clears these two when deleted_at is
--     first set. The function itself is not redefined.
--   * Same anon + authenticated select grant as every other profile column
--     today (beta). The real-login cutover closes anon reads for all of them.
--   * Not here: the admin "Hapus bio" action (a later stage). Until then a bad
--     bio can be reported (profile report) and cleared in the dashboard.
--
-- Idempotent. Rollback: supabase/rollback_profile_bio_linkedin.sql
-- Not applied to the live project by this change. Farrel applies it in the
-- SQL Editor.

alter table alumni_profiles add column if not exists bio text;
alter table alumni_profiles add column if not exists linkedin_url text;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'alumni_profiles_bio_len'
                    and conrelid = 'public.alumni_profiles'::regclass) then
    alter table alumni_profiles
      add constraint alumni_profiles_bio_len
      check (bio is null or (char_length(bio) <= 200 and btrim(bio) <> ''));
  end if;
  if not exists (select 1 from pg_constraint
                  where conname = 'alumni_profiles_linkedin_url_chk'
                    and conrelid = 'public.alumni_profiles'::regclass) then
    alter table alumni_profiles
      add constraint alumni_profiles_linkedin_url_chk
      check (linkedin_url is null
             or (char_length(linkedin_url) <= 200
                 and linkedin_url ~* '^https://([a-z0-9-]+\.)*linkedin\.com/[^[:space:]<>]*$'));
  end if;
end $$;

grant select (bio, linkedin_url) on alumni_profiles to anon, authenticated;

create or replace function alumni_profiles_clear_bio_on_delete()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    new.bio := null;
    new.linkedin_url := null;
  end if;
  return new;
end;
$$;

drop trigger if exists alumni_profiles_clear_bio_on_delete on alumni_profiles;
create trigger alumni_profiles_clear_bio_on_delete
  before update on alumni_profiles
  for each row execute function alumni_profiles_clear_bio_on_delete();
