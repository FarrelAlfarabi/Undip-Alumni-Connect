-- Suspend a user from Reports ("Block login"). All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

alter table auth.users add column if not exists email text;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com', 'clara.putri@example.com');
update alumni_profiles set user_id = null;

-- Ids saved up front: once someone is suspended, anon cannot read their row.
create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'siti', jt.pid('siti.azizah@example.com');
insert into t_ids select 'bagas', jt.pid('bagas.prasetyo@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'uahmad', gen_random_uuid();
insert into auth.users (id, email) values ((select v from t_ids where k = 'uahmad'), 'ahmad.ramadhan@example.com');

-- Fixtures (dashboard): clara is the admin. bagas sent siti a contact request.
insert into app_admins (profile_id, note) values ((select v from t_ids where k = 'clara'), 'test');
with x as (insert into contact_requests (requester_id, target_id, message)
  values ((select v from t_ids where k = 'bagas'), (select v from t_ids where k = 'siti'), 'Halo spam') returning id)
insert into t_ids select 'req', id from x;

set role anon;
select content_report_create((select v from t_ids where k = 'siti'), 'profile', (select v from t_ids where k = 'ahmad'), 'spam_or_scam', 'akun palsu');
select content_report_create((select v from t_ids where k = 'siti'), 'contact_request', (select v from t_ids where k = 'req'), 'spam_or_scam', 'pesan aneh');

-- Only an admin, only profile / contact request reports, and a reason is needed.
select jt.expect_error(format($q$select admin_reports_decide(%L, 'profile', %L, 'suspend_user', 'x')$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select jt.expect_error(format($q$select admin_reports_decide(%L, 'job', gen_random_uuid(), 'suspend_user', 'x')$q$, (select v from t_ids where k = 'clara')), 'invalid_action');
select jt.expect_error(format($q$select admin_reports_decide(%L, 'profile', %L, 'suspend_user', '  ')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'ahmad')), 'reason_required');
select jt.expect_error(format($q$select admin_reports_decide(%L, 'profile', gen_random_uuid(), 'suspend_user', 'x')$q$, (select v from t_ids where k = 'clara')), 'not_found');
-- Never an admin, never yourself.
select jt.expect_error(format($q$select admin_reports_decide(%L, 'profile', %L, 'suspend_user', 'x')$q$, (select v from t_ids where k = 'clara'), (select v from t_ids where k = 'clara')), 'invalid_state');

-- Before: Ahmad is in the Directory and can verify.
select jt.assert((select count(*) from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = 1, 'visible before');
select jt.assert((select count(*) from verify_alumni_email('ahmad.ramadhan@example.com')) = 1, 'can verify before');

-- Suspend.
select admin_reports_decide((select v from t_ids where k = 'clara'), 'profile', (select v from t_ids where k = 'ahmad'), 'suspend_user', 'Akun palsu');
select jt.assert((select count(*) from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = 0, 'gone from the Directory');
select jt.assert((select count(*) from alumni_profiles where name ilike '%ahmad%') = 0, 'gone from every list');
select jt.expect_error($q$select * from verify_alumni_email('ahmad.ramadhan@example.com')$q$, 'account_suspended');
select jt.expect_error($q$select * from verify_alumni_email('  AHMAD.Ramadhan@Example.com ')$q$, 'account_suspended');
-- Others still verify.
select jt.assert((select count(*) from verify_alumni_email('siti.azizah@example.com')) = 1, 'others unaffected');
-- The app cannot write the columns, nor touch the row.
-- Their own row is invisible, so an update touches nothing.
update alumni_profiles set suspended_at = null where id = (select v from t_ids where k = 'ahmad');
select jt.expect_error($q$update alumni_profiles set suspended_at = now()$q$, 'can be updated');
select jt.expect_error($q$update alumni_profiles set suspended_reason = 'x'$q$, 'can be updated');
-- Its open reports are closed (actioned); the person shows in the Hidden list.
select jt.assert((select count(*) from admin_reports_list((select v from t_ids where k = 'clara'), 'open') where target_type = 'profile') = 0, 'profile reports closed');
select jt.assert((select count(*) from admin_reports_list((select v from t_ids where k = 'clara'), 'hidden') where target_type = 'profile' and target_id = (select v from t_ids where k = 'ahmad') and is_hidden and hidden_reason = 'Akun palsu' and report_count = 1) = 1, 'listed as suspended with the reason');
reset role;
select jt.assert((select suspended_at is not null and suspended_reason = 'Akun palsu' from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'row carries the suspension, the app could not clear it');
select jt.assert((select verification_status from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = 'verified', 'verification untouched');

-- Real login: the claim is refused, the link is not made.
set role authenticated;
set test.uid = '';
select set_config('test.uid', (select v::text from t_ids where k = 'uahmad'), false);
select jt.expect_error($q$select claim_alumni_profile()$q$, 'account_suspended');
reset role;
select jt.assert((select user_id is null from alumni_profiles where id = (select v from t_ids where k = 'ahmad')), 'claim did not link the suspended profile');

-- Lift it.
set role anon;
select jt.expect_error(format($q$select admin_reports_decide(%L, 'profile', %L, 'unsuspend_user', null)$q$, (select v from t_ids where k = 'siti'), (select v from t_ids where k = 'ahmad')), 'not_admin');
select admin_reports_decide((select v from t_ids where k = 'clara'), 'profile', (select v from t_ids where k = 'ahmad'), 'unsuspend_user', null);
select jt.assert((select count(*) from alumni_profiles where id = (select v from t_ids where k = 'ahmad')) = 1, 'back in the Directory');
select jt.assert((select count(*) from verify_alumni_email('ahmad.ramadhan@example.com')) = 1, 'can verify again');
select jt.assert((select count(*) from admin_reports_list((select v from t_ids where k = 'clara'), 'hidden') where target_type = 'profile') = 0, 'no longer listed');

-- A contact-request report suspends the SENDER (bagas), not the receiver.
select admin_reports_decide((select v from t_ids where k = 'clara'), 'contact_request', (select v from t_ids where k = 'req'), 'suspend_user', 'Spam');
select jt.expect_error($q$select * from verify_alumni_email('bagas.prasetyo@example.com')$q$, 'account_suspended');
select jt.assert((select count(*) from verify_alumni_email('siti.azizah@example.com')) = 1, 'receiver unaffected');
select jt.assert((select count(*) from admin_reports_list((select v from t_ids where k = 'clara'), 'open') where target_type = 'contact_request') = 0, 'request report closed');
-- Lifting works from the profile row in the Hidden list.
select admin_reports_decide((select v from t_ids where k = 'clara'), 'profile', (select v from t_ids where k = 'bagas'), 'unsuspend_user', null);
select jt.assert((select count(*) from verify_alumni_email('bagas.prasetyo@example.com')) = 1, 'sender can sign in again');
reset role;

rollback;
\o
\echo suspend user checks passed
