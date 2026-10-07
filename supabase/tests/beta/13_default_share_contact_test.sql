-- Default contact to share. All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com');
update alumni_profiles set verification_status = 'unverified' where email = 'rizky.yusuf@example.com';

set role anon;
-- No direct access.
select jt.expect_error($q$select * from profile_share_defaults$q$, 'permission denied');
select jt.expect_error($q$insert into profile_share_defaults (profile_id, contact) values (gen_random_uuid(), 'x')$q$, 'permission denied');

-- Empty to begin with; any kind of text is accepted.
select jt.assert(contact_default_get(jt.pid('ahmad.ramadhan@example.com')) is null, 'no default yet');
select contact_default_set(jt.pid('ahmad.ramadhan@example.com'), '  WA +62 812-0000 / IG @ahmad / t.me/ahmad  ');
select jt.assert(contact_default_get(jt.pid('ahmad.ramadhan@example.com')) = 'WA +62 812-0000 / IG @ahmad / t.me/ahmad', 'saved and trimmed');
select contact_default_set(jt.pid('ahmad.ramadhan@example.com'), 'ahmad@example.com');
select jt.assert(contact_default_get(jt.pid('ahmad.ramadhan@example.com')) = 'ahmad@example.com', 'overwritten');
select jt.assert(contact_default_get(jt.pid('siti.azizah@example.com')) is null, 'not shared between people');

-- Rules.
select jt.expect_error(format($q$select contact_default_set(%L, %L)$q$, jt.pid('ahmad.ramadhan@example.com'), repeat('x', 201)), 'shared_too_long');
select jt.expect_error(format($q$select contact_default_set(%L, 'a')$q$, jt.pid('rizky.yusuf@example.com')), 'not_verified');

-- Empty clears it.
select contact_default_set(jt.pid('ahmad.ramadhan@example.com'), '   ');
select jt.assert(contact_default_get(jt.pid('ahmad.ramadhan@example.com')) is null, 'cleared');

-- Deleting the account removes it.
select contact_default_set(jt.pid('siti.azizah@example.com'), 'siti@example.com');
reset role;
update alumni_profiles set deleted_at = now() where email = 'siti.azizah@example.com';
select jt.assert((select count(*) from profile_share_defaults) = 0, 'account deletion removes the saved contact');

rollback;
\o
\echo default share contact checks passed
