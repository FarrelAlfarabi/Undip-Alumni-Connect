-- Undo 20261018120000_hide_nim.sql. Safe to run twice.
-- Gives anon and authenticated the table-wide select they had, NIM included.
-- Use it only together with the previous app build.
drop function if exists profile_nim(uuid, uuid);
grant select on alumni_profiles to anon, authenticated;
