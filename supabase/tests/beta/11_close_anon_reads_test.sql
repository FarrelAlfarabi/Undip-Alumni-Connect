-- Beta hardening 2: tables the app does not need are closed to the anon key.
--   email_log, conversations, messages, city_chat_messages: no access.
--   notifications: no direct select or update. Read through three functions that
--   return only the columns the screen needs (no recipient_id, actor_id, event_key).
-- All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

-- --------------------------------------------------- closed tables, as anon ---
set role anon;
select jt.expect_error($q$select * from email_log$q$, 'permission denied');
select jt.expect_error($q$insert into email_log (recipient_email, subject, body) values ('a@b.c', 's', 'b')$q$, 'permission denied');
select jt.expect_error($q$select * from conversations$q$, 'permission denied');
select jt.expect_error($q$select * from messages$q$, 'permission denied');
select jt.expect_error($q$select * from city_chat_messages$q$, 'permission denied');
select jt.expect_error(format($q$insert into city_chat_messages (sender_id, city, body) values (%L, 'Jakarta', 'x')$q$, jt.pid('siti.azizah@example.com')), 'permission denied');
select jt.expect_error($q$select * from notifications$q$, 'permission denied');
select jt.expect_error($q$select recipient_id from notifications$q$, 'permission denied');
select jt.expect_error($q$update notifications set read_at = now()$q$, 'permission denied');
reset role;

-- ---------------------------------------- notifications through functions ---
insert into notifications (recipient_id, title, body, type, target_type, target_id, actor_id, event_key, created_at) values
  (jt.pid('siti.azizah@example.com'), 'old', 'older', 'contact_request_received', 'contact_request', gen_random_uuid(), jt.pid('ahmad.ramadhan@example.com'), 'k1', now() - interval '2 hours'),
  (jt.pid('siti.azizah@example.com'), 'new', 'newer', 'report_new', 'content_report', gen_random_uuid(), jt.pid('bagas.prasetyo@example.com'), 'k2', now() - interval '1 hour'),
  (jt.pid('siti.azizah@example.com'), 'chatty', 'chat', 'chat_message', 'conversation', gen_random_uuid(), null, 'k3', now()),
  (jt.pid('ahmad.ramadhan@example.com'), 'not siti', 'x', 'contact_request_received', 'contact_request', gen_random_uuid(), null, 'k4', now());

set role anon;
-- Only that person's rows, newest first.
select jt.assert((select count(*) from notifications_list(jt.pid('siti.azizah@example.com'))) = 3, 'list returns only the recipient''s rows');
select jt.assert((select title from notifications_list(jt.pid('siti.azizah@example.com')) limit 1) = 'chatty', 'newest first');
-- The columns that identify admins and reporters are not returned.
select jt.assert(not exists (select 1 from notifications_list(jt.pid('siti.azizah@example.com')) n where to_jsonb(n) ?| array['recipient_id', 'actor_id', 'event_key']), 'no recipient_id, actor_id or event_key');
-- The columns the screen needs are.
select jt.assert(not exists (select 1 from notifications_list(jt.pid('siti.azizah@example.com')) n where not (to_jsonb(n) ?& array['id', 'job_post_id', 'title', 'body', 'read_at', 'created_at', 'type', 'target_type', 'target_id'])), 'screen columns present');
-- Nobody, or an unknown person, gets nothing.
select jt.assert((select count(*) from notifications_list(null)) = 0, 'null recipient gives nothing');
select jt.assert((select count(*) from notifications_list(gen_random_uuid())) = 0, 'unknown recipient gives nothing');

-- Unread count. Chat rows are left out unless asked for.
select jt.assert(notifications_unread_count(jt.pid('siti.azizah@example.com'), false) = 2, 'unread without chat');
select jt.assert(notifications_unread_count(jt.pid('siti.azizah@example.com'), true) = 3, 'unread with chat');
select jt.assert(notifications_unread_count(null, false) = 0, 'null recipient counts zero');

-- Mark read touches only that person, only unread rows, and returns the count.
select jt.assert(notifications_mark_read(jt.pid('siti.azizah@example.com')) = 3, 'marked three');
select jt.assert(notifications_unread_count(jt.pid('siti.azizah@example.com'), true) = 0, 'nothing unread now');
select jt.assert(notifications_unread_count(jt.pid('ahmad.ramadhan@example.com'), true) = 1, 'someone else untouched');
select jt.assert(notifications_mark_read(jt.pid('siti.azizah@example.com')) = 0, 'second call changes nothing');
select jt.assert(notifications_mark_read(null) = 0, 'null recipient marks nothing');
reset role;
select jt.assert((select min(read_at) from notifications where recipient_id = jt.pid('siti.azizah@example.com')) is not null, 'read_at really set');
select jt.assert((select read_at from notifications where title = 'not siti') is null, 'other row still unread');

-- --------------------------------------- the application trigger still works ---
-- Closing email_log must not break applying to a job.
with x as (insert into job_posts (posted_by, title, company, description) values (jt.pid('ahmad.ramadhan@example.com'), 'Staff', 'PT', 'd') returning id)
  insert into t_ids select 'job', id from x;
set role anon;
insert into job_applications (job_post_id, applicant_id, full_name, email) values ((select v from t_ids where k = 'job'), jt.pid('siti.azizah@example.com'), 'Siti', 's@example.com');
reset role;
select jt.assert((select count(*) from email_log where job_post_id = (select v from t_ids where k = 'job')) = 1, 'applying still writes the simulated email row');
select jt.assert((select count(*) from notifications where job_post_id = (select v from t_ids where k = 'job')) = 1, 'applying still notifies the poster');

-- The three functions are callable by anon and by nobody else's table rights.
select jt.assert(has_function_privilege('anon', 'notifications_list(uuid)', 'execute'), 'anon can list');
select jt.assert(has_function_privilege('anon', 'notifications_unread_count(uuid, boolean)', 'execute'), 'anon can count');
select jt.assert(has_function_privilege('anon', 'notifications_mark_read(uuid)', 'execute'), 'anon can mark read');

rollback;
\o
\echo close anon reads checks passed
