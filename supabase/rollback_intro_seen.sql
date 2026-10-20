-- Undo 20261019120000_intro_seen.sql. Safe to run twice.
-- Drops the function and the column. Everyone sees the intro again on the
-- next sign in (devices still remember it locally, so most will not).
drop function if exists account_intro_seen(uuid);
drop function if exists account_mark_intro_seen(uuid);
alter table alumni_profiles drop column if exists intro_seen_at;
