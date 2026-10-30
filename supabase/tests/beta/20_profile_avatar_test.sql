-- Profile photo: own verified profile only, link must be in the avatars bucket,
-- empty clears, readable by the API roles, listed and cleared on deletion.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com');
update alumni_profiles set verification_status = 'unverified'
  where email = 'bagas.prasetyo@example.com';

set role anon;

select profile_set_avatar(jt.pid('ahmad.ramadhan@example.com'),
  format('https://x.supabase.co/storage/v1/object/public/avatars/%s/1_me.png', jt.pid('ahmad.ramadhan@example.com')));
select jt.assert((select avatar_url from alumni_profiles where id = jt.pid('ahmad.ramadhan@example.com')) like '%/avatars/%/1_me.png', 'avatar stored and readable by the API role');
select jt.assert((select avatar_url from alumni_profiles where id = jt.pid('siti.azizah@example.com')) is null, 'other rows untouched');

-- Bad links, unknown profile and unverified profile are refused.
select jt.expect_error(format($q$select profile_set_avatar(%L, 'https://evil.example/pic.png')$q$, jt.pid('ahmad.ramadhan@example.com')), 'invalid_input');
select jt.expect_error(format($q$select profile_set_avatar(%L, 'https://x.supabase.co/storage/v1/object/public/business-photos/a.png')$q$, jt.pid('ahmad.ramadhan@example.com')), 'invalid_input');
select jt.expect_error($q$select profile_set_avatar(gen_random_uuid(), null)$q$, 'not_found');
select jt.expect_error(format($q$select profile_set_avatar(%L, 'https://x.supabase.co/storage/v1/object/public/avatars/b.png')$q$, jt.pid('bagas.prasetyo@example.com')), 'not_verified');

-- Another host, a lookalike path, and another person's folder are refused.
select jt.expect_error(format($q$select profile_set_avatar(%L, 'https://evil.example/object/public/avatars/x.png')$q$, jt.pid('ahmad.ramadhan@example.com')), 'invalid_input');
select jt.expect_error(format($q$select profile_set_avatar(%L, format('https://x.supabase.co/storage/v1/object/public/avatars/%%s/x.png', %L::text))$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com')), 'invalid_input');

-- Empty string clears.
select profile_set_avatar(jt.pid('ahmad.ramadhan@example.com'), '  ');
select jt.assert((select avatar_url from alumni_profiles where id = jt.pid('ahmad.ramadhan@example.com')) is null, 'empty clears');

-- Only the own row changes (the function takes one id and touches that row).
select profile_set_avatar(jt.pid('siti.azizah@example.com'),
  format('https://x.supabase.co/storage/v1/object/public/avatars/%s/2_a.jpg', jt.pid('siti.azizah@example.com')));
select jt.assert((select avatar_url from alumni_profiles where id = jt.pid('ahmad.ramadhan@example.com')) is null, 'ahmad unchanged by siti');

reset role;

-- Account deletion lists the file, and the link is cleared with deleted_at.
select jt.assert((select count(*) from account_files(jt.pid('siti.azizah@example.com')) where bucket = 'avatars' and path = jt.pid('siti.azizah@example.com')::text || '/2_a.jpg') = 1, 'avatar path listed for account deletion');
select jt.assert((select count(*) from account_files(jt.pid('ahmad.ramadhan@example.com')) where bucket = 'avatars') = 0, 'not other peoples avatars');
update alumni_profiles set deleted_at = now() where id = jt.pid('siti.azizah@example.com');
select jt.assert((select avatar_url from alumni_profiles where id = jt.pid('siti.azizah@example.com')) is null, 'link cleared on deletion');

rollback;
\o
\echo profile avatar checks passed
