-- Business photo: set while pending, locked once approved, shown in the
-- directory and admin list, removed with the account. All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;
insert into app_admins (profile_id, note) values (jt.pid('clara.putri@example.com'), 'test');

set role anon;

insert into t_ids select 'b1', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Foto Satu', 'd', 'Other', 'https://instagram.com/photo_one', null, 'micro');
select jt.assert((select photo_url from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')) is null, 'no photo by default');

-- Owner sets a photo on a pending business.
select business_set_photo(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'),
  'https://x.supabase.co/storage/v1/object/public/business-photos/AHMADID/1_logo.png');
select jt.assert((select photo_url from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')) like '%/business-photos/AHMADID/1_logo.png', 'photo stored');
select jt.assert((select photo_url from admin_business_photo_urls(jt.pid('clara.putri@example.com')) where business_id = (select v from t_ids where k = 'b1')) like '%/business-photos/AHMADID/1_logo.png', 'admin sees the photo');
select jt.expect_error(format($q$select admin_business_photo_urls(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
-- Not shown in the directory while pending.
select jt.assert((select count(*) from business_photo_urls(jt.pid('siti.azizah@example.com')) where business_id = (select v from t_ids where k = 'b1')) = 0, 'pending photo is not public');

-- Wrong owner, bad link and unknown business are refused.
select jt.expect_error(format($q$select business_set_photo(%L, %L, 'https://x.supabase.co/storage/v1/object/public/business-photos/a.png')$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b1')), 'not_owner');
select jt.expect_error(format($q$select business_set_photo(%L, %L, 'https://evil.example/pic.png')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'invalid_input');
select jt.expect_error(format($q$select business_set_photo(%L, gen_random_uuid(), null)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_found');

-- Approved businesses show the photo in the directory.
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b1'), 'approve', 'micro', null);
select jt.assert((select photo_url from business_photo_urls(jt.pid('siti.azizah@example.com')) where business_id = (select v from t_ids where k = 'b1')) like '%/business-photos/AHMADID/1_logo.png', 'directory photo is returned once approved');

-- Locked once approved: cannot be swapped or removed.
select jt.expect_error(format($q$select business_set_photo(%L, %L, null)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'locked');

-- A rejected business can change its photo, and remove it with null.
insert into t_ids select 'b2', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Foto Dua', 'd', 'Other', 'https://instagram.com/photo_two', null, 'micro');
select business_set_photo(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b2'), 'https://x.supabase.co/storage/v1/object/public/business-photos/AHMADID/2_a.jpg');
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b2'), 'reject', null, 'blur');
select business_set_photo(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b2'), null);
select jt.assert((select photo_url from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b2')) is null, 'photo removed with null');

-- Deleting an account removes the photo files too.
reset role;
select jt.assert((select count(*) from account_files(jt.pid('ahmad.ramadhan@example.com')) where bucket = 'business-photos' and path = 'AHMADID/1_logo.png') = 1, 'photo path listed for account deletion');
select jt.assert((select count(*) from account_files(jt.pid('siti.azizah@example.com')) where bucket = 'business-photos') = 0, 'not other peoples photos');

rollback;
\o
\echo business photo checks passed
