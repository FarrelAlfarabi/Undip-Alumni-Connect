-- Delete own content, cancel a contact request, admin approve without band,
-- undo helpers and the pending counts. All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');

set role anon;

-- ---- business: admin approves with no band, then undoes, then owner deletes
insert into t_ids select 'b1', id from business_register((select v from t_ids where k = 'ahmad'), 'Kopi Ahmad', 'Kopi', 'Food & Drink', 'https://www.instagram.com/kopi_ahmad/', null, 'small');
select jt.assert((select band from (select (admin_business_decide((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'b1'), 'approve', null, null)).approved_band as band) q) = 'small', 'approve without band uses the owner band');
select jt.expect_error(format($q$select admin_business_set_state(%L, %L, 'pending', null, null)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'b1')), 'not_admin');
select admin_business_set_state((select v from t_ids where k = 'clara'), (select v from t_ids where k = 'b1'), 'pending', null, null);
select jt.assert((select (admin_pending_counts((select v from t_ids where k = 'clara'))).businesses) = 1, 'pending business is counted');
select jt.expect_error(format($q$select admin_pending_counts(%L)$q$, (select v from t_ids where k = 'siti')), 'not_admin');

select jt.expect_error(format($q$select business_delete(%L, %L)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'b1')), 'not_owner');
select business_delete((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1'));
select jt.expect_error(format($q$select business_delete(%L, %L)$q$, (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'b1')), 'not_found');

-- ---- job post: only the poster deletes; applications go with it
reset role;
insert into job_posts (posted_by, title, company, description) values ((select v from t_ids where k = 'ahmad'), 'Analyst', 'Bank', 'Kerja');
insert into t_ids select 'job', id from job_posts where title = 'Analyst';
insert into job_applications (job_post_id, applicant_id, full_name, email) values ((select v from t_ids where k = 'job'), (select v from t_ids where k = 'siti'), 'Siti', 'siti@example.com');
set role anon;
select job_application_withdraw((select v from t_ids where k = 'siti'), (select v from t_ids where k = 'job'));
select jt.assert(not job_application_exists((select v from t_ids where k = 'siti'), (select v from t_ids where k = 'job')), 'application withdrawn');
select jt.expect_error(format($q$select job_post_delete(%L, %L)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'job')), 'not_owner');
select job_post_delete((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'job'));
select jt.assert((select count(*) from job_posts where title = 'Analyst') = 0, 'job deleted');

-- ---- announcement: admin deletes and restores
select admin_announcement_create((select v from t_ids where k = 'clara'), 'Reuni', 'Sabtu depan');
select jt.expect_error(format($q$select admin_announcement_delete(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.assert((select count(*) from announcements where title = 'Reuni') = 1, 'announcement exists');
select admin_announcement_delete((select v from t_ids where k = 'clara'), (select id from announcements where title = 'Reuni'));
select jt.assert((select count(*) from announcements where title = 'Reuni') = 0, 'announcement deleted');

-- ---- contact request: cancel frees the pair and starts no cool-down
select contact_request_send((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'siti'), 'Halo');
reset role;
insert into t_ids select 'req', id from contact_requests where requester_id = (select v from t_ids where k = 'ahmad') and target_id = (select v from t_ids where k = 'siti');
set role anon;
select jt.expect_error(format($q$select contact_request_cancel(%L, %L)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'req')), 'not_requester');
select contact_request_cancel((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'req'));
select jt.assert((select count(*) from contact_requests_outgoing((select v from t_ids where k = 'ahmad'))) = 0, 'cancelled is not listed');
select jt.assert((select count(*) from contact_requests_incoming((select v from t_ids where k = 'siti'))) = 0, 'cancelled is not listed for the target');
select jt.expect_error(format($q$select contact_request_cancel(%L, %L)$q$, (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'req')), 'invalid_state');
select contact_request_send((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'siti'), 'Halo lagi');

-- ---- products: price may be empty only when negotiable; city may be empty
reset role;
select jt.expect_error(format($q$insert into marketplace_listings (seller_id, title, description, price_idr, category, image_url, contact_info, status)
  values (%L, 'Tanpa harga', 'd', null, 'Other', 'https://x/y.png', 'wa', 'approved')$q$, (select v from t_ids where k = 'ahmad')), 'price_needed');
insert into marketplace_listings (seller_id, title, description, price_idr, price_negotiable, category, city, image_url, contact_info, status)
  values ((select v from t_ids where k = 'ahmad'), 'Nego tanpa harga', 'd', null, true, 'Other', null, 'https://x/y.png', 'wa', 'approved');
select jt.assert((select count(*) from marketplace_listings where title = 'Nego tanpa harga' and price_idr is null and city is null) = 1, 'negotiable product without price or city');


\o
select 'ok';
-- Stage 5: admin Jobs list
select jt.expect_error(format($q$select * from admin_jobs_list(%L, null)$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.assert((select count(*) from admin_jobs_list((select v from t_ids where k = 'clara'), null)) >= 0, 'admin can list jobs');
-- Stage 6: marketplace reports tab and announcement home order
select jt.expect_error(format($q$select * from marketplace_report_details(%L, 'open')$q$, (select v from t_ids where k = 'siti')), 'not_admin');
select jt.assert((select count(*) from marketplace_report_details((select v from t_ids where k = 'clara'), 'open')) >= 0, 'admin can list report details');
select jt.expect_error(format($q$select marketplace_reports_set_dismissed(%L, gen_random_uuid(), true)$q$, (select v from t_ids where k = 'clara')), 'not_found');
insert into announcements (title, body, posted_by) values ('Urut A', 'x', (select v from t_ids where k = 'clara'));
select admin_set_home_order((select v from t_ids where k = 'clara'), 'announcement', array[(select id from announcements where title = 'Urut A')]);
select jt.assert((select home_rank from announcements where title = 'Urut A') = 1, 'announcement pinned first');
-- Stage 7: applications are private
select jt.expect_error(format($q$select * from job_applicants_list(%L, gen_random_uuid())$q$, (select v from t_ids where k = 'siti')), 'not_owner');
select jt.assert(not has_table_privilege('authenticated', 'job_applications', 'select'), 'members cannot read job_applications directly');
select jt.assert(job_application_exists((select v from t_ids where k = 'siti'), gen_random_uuid()) = false, 'no application yet');
-- Stage 7: close/edit own job, clear notifications
reset role;
insert into job_posts (posted_by, title, company, description) values ((select v from t_ids where k = 'ahmad'), 'Tutup Saya', 'PT A', 'Kerja');
insert into t_ids select 'job2', id from job_posts where title = 'Tutup Saya';
set role anon;
select jt.expect_error(format($q$select job_post_set_closed(%L, %L, true)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'job2')), 'not_owner');
select job_post_set_closed((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'job2'), true);
select jt.assert((select closed_at is not null from job_posts where id = (select v from t_ids where k = 'job2')), 'job closed');
select job_post_update((select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'job2'), 'Judul Baru', 'PT B', 'Deskripsi', null);
select jt.assert((select title = 'Judul Baru' from job_posts where id = (select v from t_ids where k = 'job2')), 'job edited');
select jt.expect_error(format($q$select job_post_update(%L, %L, 'x', 'PT', 'd', null)$q$, (select v from t_ids where k = 'ahmad'), (select v from t_ids where k = 'job2')), 'invalid_input');
select notifications_clear((select v from t_ids where k = 'siti'));
select jt.assert((select count(*) from notifications_list((select v from t_ids where k = 'siti'))) = 0, 'notifications cleared');
rollback;
