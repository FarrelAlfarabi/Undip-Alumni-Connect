-- Review fixes (30 Oct 2026): a hidden category cannot be picked through the
-- API (also inside the security definer functions), the dashboard still can;
-- the avatars bucket has no list policy; a photo link must point to the
-- person's own folder, also when written straight to the table.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com');

update categories set active = false where name = 'Electronics';

-- An API request (PostgREST sets request.jwt.claims) cannot switch an item to
-- a hidden category, even as the table owner, as inside an RPC.
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select jt.expect_error($q$update marketplace_listings set category = 'Electronics' where id = (select id from marketplace_listings where category <> 'Electronics' limit 1)$q$, 'invalid_category');
-- An item that already has the hidden category can still be saved.
update marketplace_listings set title = title where category = 'Electronics';

-- The service role through the API, and the dashboard (no claims), may.
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
update marketplace_listings set category = 'Electronics' where id = (select id from marketplace_listings where category <> 'Electronics' limit 1);
select set_config('request.jwt.claims', '', true);
update marketplace_listings set category = 'Electronics' where id = (select id from marketplace_listings where category <> 'Electronics' limit 1);

-- Directly as anon (no RPC) it is refused too.
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set role anon;
select jt.expect_error($q$update businesses set category = 'Electronics'$q$, 'invalid_category|permission denied|row-level security');
reset role;
select set_config('request.jwt.claims', '', true);

-- No select policy on the avatars bucket (a public bucket serves by link).
select jt.assert(not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'avatars_public_read'), 'no avatars list policy');

-- The table refuses a link to another person's folder or with extra text.
select jt.expect_error(format($q$update alumni_profiles set avatar_url = format('https://x.supabase.co/storage/v1/object/public/avatars/%%s/1_me.png', %L::text) where id = %L$q$, jt.pid('siti.azizah@example.com'), jt.pid('ahmad.ramadhan@example.com')), 'alumni_profiles_avatar_url_check');
select jt.expect_error(format($q$update alumni_profiles set avatar_url = format('https://x.supabase.co/storage/v1/object/public/avatars/%%s/1_me.png?x', %L::text) where id = %L$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('ahmad.ramadhan@example.com')), 'alumni_profiles_avatar_url_check');
-- The own folder still works, through the function and directly.
select profile_set_avatar(jt.pid('ahmad.ramadhan@example.com'),
  format('https://x.supabase.co/storage/v1/object/public/avatars/%s/1_me.png', jt.pid('ahmad.ramadhan@example.com')));
select jt.assert((select avatar_url from alumni_profiles where id = jt.pid('ahmad.ramadhan@example.com')) like '%/1_me.png', 'own photo saved');

rollback;
\o
\echo review security fixes checks passed
