-- Undo 20261030140000_profile_bio_linkedin.sql. Safe to run twice.
-- Deploy the previous app build FIRST: the current build names bio and
-- linkedin_url in its profile reads, which fail once the columns are gone.
-- This deletes every bio and LinkedIn link people entered. Export them first
-- if you want to keep them:
--   create table profile_bio_backup as
--   select id, bio, linkedin_url from alumni_profiles
--   where bio is not null or linkedin_url is not null;
drop trigger if exists alumni_profiles_clear_bio_on_delete on alumni_profiles;
drop function if exists alumni_profiles_clear_bio_on_delete();
alter table alumni_profiles drop constraint if exists alumni_profiles_bio_len;
alter table alumni_profiles drop constraint if exists alumni_profiles_linkedin_url_chk;
alter table alumni_profiles drop column if exists bio;
alter table alumni_profiles drop column if exists linkedin_url;
