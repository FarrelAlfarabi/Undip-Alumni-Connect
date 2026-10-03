-- Stage 6F: feedback reports. The app role can only INSERT. Admins read and
-- change the status only through admin functions.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com');
insert into app_admins (profile_id, note) values (jt.pid('clara.putri@example.com'), 'A');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

set role anon;

-- Insert works, with or without a profile (errors can happen before verification).
insert into feedback_reports (profile_id, message, error_text, screen, app_version, build_number, platform)
  values (jt.pid('ahmad.ramadhan@example.com'), 'Saya menekan tombol kirim', 'Could not load jobs', 'Job Board', '0.9.0', '12', 'android');
insert into feedback_reports (profile_id, error_text, screen, app_version, build_number, platform)
  values (null, 'Could not verify', 'Verification', '0.9.0', '12', 'android');
-- Everything optional really is optional.
insert into feedback_reports (profile_id) values (jt.pid('ahmad.ramadhan@example.com'));

-- The app can never read, change or delete.
select jt.expect_error($q$select * from feedback_reports$q$, 'permission denied');
select jt.expect_error($q$select count(*) from feedback_reports$q$, 'permission denied');
select jt.expect_error($q$update feedback_reports set status = 'done'$q$, 'permission denied');
select jt.expect_error($q$delete from feedback_reports$q$, 'permission denied');
-- Back-dating does not help: the database sets the time.
insert into feedback_reports (profile_id, message, created_at) values (jt.pid('clara.putri@example.com'), 'backdated', now() - interval '10 days');
select jt.assert((select created_at from admin_feedback_list(jt.pid('clara.putri@example.com')) where message = 'backdated') > now() - interval '1 minute', 'created_at is set by the database');
-- A "returning" clause is a read too.
select jt.expect_error(format($q$insert into feedback_reports (profile_id) values (%L) returning id$q$, jt.pid('ahmad.ramadhan@example.com')), 'permission denied');

-- Length limits.
select jt.expect_error($q$insert into feedback_reports (message) values (repeat('x', 501))$q$, 'violates check constraint');
select jt.expect_error($q$insert into feedback_reports (error_text) values (repeat('x', 301))$q$, 'violates check constraint');
select jt.expect_error($q$insert into feedback_reports (screen) values (repeat('x', 61))$q$, 'violates check constraint');
select jt.expect_error($q$insert into feedback_reports (app_version) values (repeat('x', 31))$q$, 'violates check constraint');
-- The status cannot be chosen by the app.
select jt.expect_error($q$insert into feedback_reports (status) values ('done')$q$, 'row-level security|violates');
-- An unknown profile id is refused.
select jt.expect_error($q$insert into feedback_reports (profile_id) values (gen_random_uuid())$q$, 'violates foreign key');

-- Daily limit: 10 per profile per day. Siti sends 10, the 11th is refused.
do $$
begin
  for i in 1..10 loop
    insert into feedback_reports (profile_id, message) values (jt.pid('siti.azizah@example.com'), 'm' || i);
  end loop;
end $$;
select jt.expect_error(format($q$insert into feedback_reports (profile_id, message) values (%L, 'too many')$q$, jt.pid('siti.azizah@example.com')), 'feedback_daily_limit');
-- Another profile is not affected.
insert into feedback_reports (profile_id, message) values (jt.pid('ahmad.ramadhan@example.com'), 'still ok');
-- Without a profile id only the length limits apply.
do $$
begin
  for i in 1..15 loop
    insert into feedback_reports (message) values ('anon ' || i);
  end loop;
end $$;

-- Admin functions: a non-admin is refused, an admin reads and sets the status.
select jt.expect_error(format($q$select * from admin_feedback_list(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
select jt.expect_error(format($q$select admin_feedback_new_count(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
select jt.expect_error(format($q$select admin_feedback_set_status(%L, gen_random_uuid(), 'seen')$q$, jt.pid('siti.azizah@example.com')), 'not_admin');

select jt.assert(admin_feedback_new_count(jt.pid('clara.putri@example.com')) = 30, 'new count covers every row');
select jt.assert((select count(*) from admin_feedback_list(jt.pid('clara.putri@example.com'))) = 30, 'admin sees all 30');
select jt.assert((select count(*) from admin_feedback_list(jt.pid('clara.putri@example.com')) where error_text = 'Could not load jobs' and screen = 'Job Board' and profile_name is not null) = 1, 'row has screen, error and the sender name');
select jt.assert((select count(*) from admin_feedback_list(jt.pid('clara.putri@example.com')) where error_text = 'Could not verify' and profile_name is null) = 1, 'a row without a profile has no name');
-- Newest first.
select jt.assert((select message from admin_feedback_list(jt.pid('clara.putri@example.com')) limit 1) = 'anon 15', 'newest first');

select admin_feedback_set_status(jt.pid('clara.putri@example.com'), (select id from admin_feedback_list(jt.pid('clara.putri@example.com')) where message = 'anon 1'), 'seen');
select admin_feedback_set_status(jt.pid('clara.putri@example.com'), (select id from admin_feedback_list(jt.pid('clara.putri@example.com')) where message = 'anon 2'), 'done');
select jt.assert(admin_feedback_new_count(jt.pid('clara.putri@example.com')) = 28, 'seen and done are not new any more');
select jt.expect_error(format($q$select admin_feedback_set_status(%L, gen_random_uuid(), 'banana')$q$, jt.pid('clara.putri@example.com')), 'invalid_status');
select jt.expect_error(format($q$select admin_feedback_set_status(%L, gen_random_uuid(), 'seen')$q$, jt.pid('clara.putri@example.com')), 'not_found');
reset role;

-- The dashboard can read everything, and no notification was created for feedback.
select jt.assert((select count(*) from feedback_reports) = 30, 'dashboard reads all rows');
select jt.assert((select count(*) from notifications where type like 'feedback%') = 0, 'no notification for feedback');

rollback;
\o
\echo feedback checks passed
