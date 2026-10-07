-- Beta feedback round: personal business, 3 business limit, unseen reports.
-- All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;
insert into app_admins (profile_id, note) values (jt.pid('clara.putri@example.com'), 'test');

set role anon;

-- Personal flag: default false, true when asked, old 7 argument call still works.
insert into t_ids select 'b1', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Satu', 'd', 'Other', 'https://instagram.com/limit_one', null, 'micro');
insert into t_ids select 'b2', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Dua', 'd', 'Other', 'https://instagram.com/limit_two', null, 'micro', true);
select jt.assert((select is_personal from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')) = false, 'default is not personal');
select jt.assert((select is_personal from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b2')) = true, 'personal flag stored');
insert into t_ids select 'b3', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Tiga', 'd', 'Other', 'https://instagram.com/limit_three', null, 'micro');

-- Fourth business is refused; another owner is not affected.
select jt.expect_error(format($q$select business_register(%L, 'Empat', 'd', 'Other', 'https://instagram.com/limit_four', null, 'micro')$q$, jt.pid('ahmad.ramadhan@example.com')), 'business_limit');
insert into t_ids select 'siti1', id from business_register(jt.pid('siti.azizah@example.com'), 'Siti Satu', 'd', 'Other', 'https://instagram.com/siti_one', null, 'micro');

-- Edit can change the personal flag; null keeps it.
select business_update(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), 'Satu', 'd', 'Other', 'https://instagram.com/limit_one', null, true);
select jt.assert((select is_personal from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')) = true, 'edit sets personal');
select business_update(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), 'Satu', 'd', 'Other', 'https://instagram.com/limit_one', null);
select jt.assert((select is_personal from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')) = true, 'null keeps personal');

-- A rejected business does not count; sending it again needs a free slot.
reset role;
update businesses set status = 'rejected', rejection_reason = 'x' where id = (select v from t_ids where k = 'b3');
set role anon;
insert into t_ids select 'b4', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Empat', 'd', 'Other', 'https://instagram.com/limit_four', null, 'micro');
select jt.expect_error(format($q$select business_update(%L, %L, 'Tiga', 'd', 'Other', 'https://instagram.com/limit_three', null)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b3')), 'business_limit');

-- Unseen reports: admin only, counted, cleared by mark_seen.
select jt.expect_error(format($q$select admin_reports_unseen_count(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
select jt.expect_error(format($q$select admin_reports_mark_seen(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');
reset role;
select jt.assert(admin_reports_unseen_count(jt.pid('clara.putri@example.com')) = 0, 'no reports yet');
insert into content_reports (reporter_id, target_type, target_id, reason)
  values (jt.pid('siti.azizah@example.com'), 'business', (select v from t_ids where k = 'b1'), 'other');
select jt.assert(admin_reports_unseen_count(jt.pid('clara.putri@example.com')) = 1, 'one unseen report');
select admin_reports_mark_seen(jt.pid('clara.putri@example.com'));
select jt.assert(admin_reports_unseen_count(jt.pid('clara.putri@example.com')) = 0, 'seen reports are not counted');
-- The report is still open.
select jt.assert((select count(*) from content_reports where status = 'open') = 1, 'mark_seen does not close reports');

rollback;
\o
\echo beta feedback round checks passed
