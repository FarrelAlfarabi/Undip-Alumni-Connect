-- Edit an approved business, with admin approval.
-- The old version stays until approval; owner touches only own requests;
-- only admins decide; a changed NIB loses its tick; the band never changes.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified', user_id = null, suspended_at = null
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
delete from app_admins;
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

set role anon;

insert into t_ids select 'b1', id from business_register((select v from t_ids where k = 'ahmad'), 'Kopi Lama', 'Deskripsi lama', 'Other', 'https://instagram.com/kopi_lama', null, 'micro');
insert into t_ids select 'b2', id from business_register((select v from t_ids where k = 'siti'), 'Toko Siti', 'd', 'Other', 'https://instagram.com/toko_siti_x', null, 'small');

-- Not approved yet: the normal form is used, a change request is refused.
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Other', 'https://instagram.com/kopi_lama', null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'locked');

select admin_business_decide((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'b1'), 'approve', null, null);
select admin_business_decide((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'b2'), 'approve', null, null);
select business_set_nib((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1'), '1111111111111');
select admin_business_nib_verify((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'b1'), true);

-- Validation and ownership.
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Other', 'https://instagram.com/kopi_lama', null, false, null, null)$q$,
  (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'b1')), 'not_owner');
select jt.expect_error(format($q$select business_edit_request_submit(%L, gen_random_uuid(), 'Kopi Baru', 'd', 'Other', 'https://instagram.com/kopi_lama', null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad')), 'not_found');
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'K', 'd', 'Other', 'https://instagram.com/kopi_lama', null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'invalid_input');
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Other', null, null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'link_required');
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Other', 'bukan link', null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'invalid_link');
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Other', 'https://instagram.com/toko_siti_x', null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'link_in_use');
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Other', 'https://instagram.com/kopi_lama', null, false, '123', null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'invalid_nib');
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Other', 'https://instagram.com/kopi_lama', null, false, null, 'https://evil.example/x.png')$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'invalid_input');
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Tidak Ada', 'https://instagram.com/kopi_lama', null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'invalid_category');
-- A photo must be this owner's own file in our bucket.
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Other', 'https://instagram.com/kopi_lama', null, false, null, 'https://evil.example/a/object/public/business-photos/x.png')$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'invalid_input');
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Baru', 'd', 'Other', 'https://instagram.com/kopi_lama', null, false, null, 'https://x.supabase.co/storage/v1/object/public/business-photos/%s/x.png')$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1'), (select v from t_ids where k = 'siti')), 'invalid_input');
-- Nothing changed: refused.
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Kopi Lama', 'Deskripsi lama', 'Other', 'https://instagram.com/kopi_lama', null, false, '1111111111111', null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'no_change');

-- A valid request is stored apart. The business keeps its old values.
insert into t_ids select 'r1', (business_edit_request_submit((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1'),
  'Kopi Baru', 'Deskripsi baru', 'Other', 'https://instagram.com/kopi_baru', 'https://kopibaru.example', false, '2222222222222', null)).id;
select jt.assert((select name = 'Kopi Lama' and description = 'Deskripsi lama' and social_link = 'https://instagram.com/kopi_lama' and nib = '1111111111111' and nib_verified
  from business_my((select v from t_ids where k = 'ahmad')) where id = (select v from t_ids where k = 'b1')), 'old version untouched while pending');
select jt.assert((select count(*) from business_directory((select v from t_ids where k = 'siti')) where name = 'Kopi Lama') = 1, 'others still see the old name');
select jt.assert((select count(*) from business_directory((select v from t_ids where k = 'siti')) where name = 'Kopi Baru') = 0, 'others do not see the new name');
select jt.assert((select count(*) from business_edit_request_my((select v from t_ids where k = 'ahmad'))) = 1, 'owner sees the open request');
select jt.assert((select count(*) from business_edit_request_my((select v from t_ids where k = 'siti'))) = 0, 'other people do not see it');

-- Sending again replaces the values of the open request (still one).
select business_edit_request_submit((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1'),
  'Kopi Baru 2', 'Deskripsi baru', 'Other', 'https://instagram.com/kopi_baru', null, false, '2222222222222', null);
select jt.assert((select count(*) = 1 and bool_and(name = 'Kopi Baru 2') from business_edit_request_my((select v from t_ids where k = 'ahmad'))), 'resend replaces the open request');

-- The tables are closed: no direct reads or writes.
select jt.expect_error($q$select * from business_edit_requests$q$, 'permission denied');
select jt.expect_error(format($q$update business_edit_requests set status = 'approved' where id = %L$q$, (select v from t_ids where k = 'r1')), 'permission denied');

-- Owner cannot decide; a stranger cannot cancel.
select jt.expect_error(format($q$select admin_business_edit_decide(%L, %L, 'approve', null)$q$, (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'r1')), 'not_admin');
select jt.expect_error(format($q$select admin_business_edit_requests(%L)$q$, (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.expect_error(format($q$select admin_business_edit_pending_count(%L)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.expect_error(format($q$select business_edit_request_cancel(%L, %L)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'r1')), 'not_owner');

-- Admin list shows old next to new, and the count.
select jt.assert((select count(*) from admin_business_edit_requests((select v from t_ids where k = 'clara'))) = 1, 'admin sees one pending');
select jt.assert((select old_name = 'Kopi Lama' and new_name = 'Kopi Baru 2' and old_nib = '1111111111111' and new_nib = '2222222222222' and old_nib_verified
  from admin_business_edit_requests((select v from t_ids where k = 'clara')) limit 1), 'old vs new');
select jt.assert(admin_business_edit_pending_count((select v from t_ids where k = 'clara')) = 1, 'count is 1');

-- Reject needs a reason, then the owner is told and the business is unchanged.
select jt.expect_error(format($q$select admin_business_edit_decide(%L, %L, 'reject', null)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'r1')), 'reason_required');
select jt.expect_error(format($q$select admin_business_edit_decide(%L, %L, 'maybe', null)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'r1')), 'invalid_action');
select admin_business_edit_decide((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'r1'), 'reject', 'Nama terlalu mirip bisnis lain');
select jt.assert((select name = 'Kopi Lama' from business_my((select v from t_ids where k = 'ahmad')) where id = (select v from t_ids where k = 'b1')), 'rejected: old version stays');
select jt.assert((select status = 'rejected' and reject_reason = 'Nama terlalu mirip bisnis lain' from business_edit_request_my((select v from t_ids where k = 'ahmad'))), 'owner sees the reason');
reset role;
select jt.assert((select count(*) from notifications where recipient_id = (select v from t_ids where k = 'ahmad') and type = 'business_edit_rejected') = 1, 'owner notified of rejection');
set role anon;
select jt.expect_error(format($q$select admin_business_edit_decide(%L, %L, 'approve', null)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'r1')), 'invalid_state');

-- Owner sends a new one, then cancels it.
insert into t_ids select 'r2', (business_edit_request_submit((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1'),
  'Kopi Cancel', 'Deskripsi lama', 'Other', 'https://instagram.com/kopi_lama', null, false, '1111111111111', null)).id;
select business_edit_request_cancel((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'r2'));
select jt.assert((select count(*) from business_edit_request_my((select v from t_ids where k = 'ahmad'))) = 0, 'cancelled request is gone from the owner list');
select jt.expect_error(format($q$select business_edit_request_cancel(%L, %L)$q$, (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'r2')), 'invalid_state');
select jt.expect_error(format($q$select admin_business_edit_decide(%L, %L, 'approve', null)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'r2')), 'invalid_state');

-- Approve: values go live, NIB tick is lost, band and status stay.
insert into t_ids select 'r3', (business_edit_request_submit((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1'),
  'Kopi Baru', 'Deskripsi baru', 'Other', 'https://instagram.com/kopi_baru', 'https://kopibaru.example', false, '2222222222222', null)).id;
select admin_business_edit_decide((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'r3'), 'approve', null);
select jt.assert((select name = 'Kopi Baru' and description = 'Deskripsi baru' and social_link = 'https://instagram.com/kopi_baru'
                         and website_link = 'https://kopibaru.example' and nib = '2222222222222' and not nib_verified
                         and status = 'approved' and approved_band = 'micro' and requested_band = 'micro'
  from business_my((select v from t_ids where k = 'ahmad')) where id = (select v from t_ids where k = 'b1')), 'approved: new values live, tick gone, band and status kept');
select jt.assert((select count(*) from business_directory((select v from t_ids where k = 'siti')) where name = 'Kopi Baru') = 1, 'others now see the new name');
select jt.assert((select count(*) from business_edit_request_my((select v from t_ids where k = 'ahmad'))) = 0, 'no open request after approval');
reset role;
select jt.assert((select count(*) from notifications where recipient_id = (select v from t_ids where k = 'ahmad') and type = 'business_edit_approved') = 1, 'owner notified of approval');
set role anon;
select jt.assert(admin_business_edit_pending_count((select v from t_ids where k = 'clara')) = 0, 'count back to 0');

-- Unchanged NIB keeps its tick when other fields change.
select admin_business_nib_verify((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'b1'), true);
select admin_business_edit_decide((select v from t_ids where k = 'clara'),
  (business_edit_request_submit((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1'),
    'Kopi Baru', 'Deskripsi ketiga', 'Other', 'https://instagram.com/kopi_baru', 'https://kopibaru.example', false, '2222222222222', null)).id, 'approve', null);
select jt.assert((select nib_verified and description = 'Deskripsi ketiga' from business_my((select v from t_ids where k = 'ahmad')) where id = (select v from t_ids where k = 'b1')), 'same NIB keeps the tick');

-- A link another business took while the request waited is refused at approval.
insert into t_ids select 'r4', (business_edit_request_submit((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1'),
  'Kopi Baru', 'Deskripsi ketiga', 'Other', 'https://instagram.com/akan_diambil', 'https://kopibaru.example', false, '2222222222222', null)).id;
reset role;
update businesses set social_link = 'https://instagram.com/akan_diambil' where id = (select v from t_ids where k = 'b2');
set role anon;
select jt.expect_error(format($q$select admin_business_edit_decide(%L, %L, 'approve', null)$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'r4')), 'link_in_use');

-- A suspended member cannot send requests.
reset role;
update alumni_profiles set suspended_at = now() where id = (select v from t_ids where k = 'ahmad');
set role anon;
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Lain', 'd', 'Other', 'https://instagram.com/kopi_baru', null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'not_verified');
reset role;
update alumni_profiles set suspended_at = null where id = (select v from t_ids where k = 'ahmad');
set role anon;

-- A suspended business cannot take a change.
select admin_business_edit_decide((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'r4'), 'reject', 'Link bentrok');
select admin_business_decide((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'b1'), 'suspend', null, 'tes');
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Lain', 'd', 'Other', 'https://instagram.com/kopi_baru', null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'locked');

-- Admins are told about a new request (type business_edit_pending).
reset role;
select jt.assert((select count(*) from notifications where recipient_id = (select v from t_ids where k = 'clara') and type = 'business_edit_pending') >= 3, 'admin notified');

-- Real login on: the owner id must be the signed-in one.
insert into t_ids select 'uahmad', gen_random_uuid();
insert into t_ids select 'usiti', gen_random_uuid();
insert into auth.users (id, email) values ((select v from t_ids where k = 'uahmad'), 'ahmad.ramadhan@example.com'), ((select v from t_ids where k = 'usiti'), 'siti.azizah@example.com');
update alumni_profiles set user_id = (select v from t_ids where k = 'uahmad') where id = (select v from t_ids where k = 'ahmad');
update alumni_profiles set user_id = (select v from t_ids where k = 'usiti') where id = (select v from t_ids where k = 'siti');
update businesses set status = 'approved' where id = (select v from t_ids where k = 'b1');
update app_settings set value = 'on' where key = 'require_login';
set role anon;
select set_config('test.uid', (select v::text from t_ids where k = 'usiti'), false);
select jt.expect_error(format($q$select business_edit_request_submit(%L, %L, 'Curang', 'd', 'Other', 'https://instagram.com/kopi_baru', null, false, null, null)$q$,
  (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'not_signed_in|not_you|forbidden|not_owner');
select jt.expect_error(format($q$select business_edit_request_my(%L)$q$, (select v from t_ids where k = 'ahmad')), 'not_signed_in|not_you|forbidden');
select jt.expect_error(format($q$select admin_business_edit_requests(%L)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
reset role;

rollback;
\o
\echo business edit request checks passed
