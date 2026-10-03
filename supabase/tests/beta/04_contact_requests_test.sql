-- Stage 6B: request to contact. All app calls run as the anon role.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com', 'clara.putri@example.com');
update alumni_profiles set verification_status = 'unverified' where email = 'rizky.yusuf@example.com';

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

set role anon;

-- No direct table access.
select jt.expect_error($q$select * from contact_requests$q$, 'permission denied');
select jt.expect_error($q$select shared_contact from contact_requests$q$, 'permission denied');
select jt.expect_error(format($q$insert into contact_requests (requester_id, target_id) values (%L, %L)$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com')), 'permission denied');
select jt.expect_error($q$update contact_requests set status = 'accepted'$q$, 'permission denied');
select jt.expect_error($q$delete from contact_requests$q$, 'permission denied');

-- Send.
insert into t_ids select 'r1', id from contact_request_send(jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com'), 'Halo, boleh kenalan?');
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'x')$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('ahmad.ramadhan@example.com')), 'cannot_request_self');
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'x')$q$, jt.pid('rizky.yusuf@example.com'), jt.pid('siti.azizah@example.com')), 'not_verified');
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'x')$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('rizky.yusuf@example.com')), 'not_verified');
select jt.expect_error(format($q$select contact_request_send(%L, gen_random_uuid(), 'x')$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_verified');
select jt.expect_error(format($q$select contact_request_send(%L, %L, %L)$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('bagas.prasetyo@example.com'), repeat('a', 201)), 'message_too_long');
-- A message is optional.
insert into t_ids select 'r_nomsg', id from contact_request_send(jt.pid('ahmad.ramadhan@example.com'), jt.pid('bagas.prasetyo@example.com'), null);
-- One open request per pair.
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'lagi')$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com')), 'request_already_open');

-- Incoming and outgoing lists never carry the shared contact.
select jt.assert((select count(*) from contact_requests_incoming(jt.pid('siti.azizah@example.com'))) = 1, 'siti sees one incoming request');
select jt.assert((select message from contact_requests_incoming(jt.pid('siti.azizah@example.com'))) = 'Halo, boleh kenalan?', 'message shown');
select jt.assert((select count(*) from contact_requests_incoming(jt.pid('clara.putri@example.com'))) = 0, 'someone else sees nothing');
select jt.assert((select count(*) from contact_requests_outgoing(jt.pid('ahmad.ramadhan@example.com'))) = 2, 'ahmad sees his two outgoing requests');
select jt.assert((select contact_requests_pending_count(jt.pid('siti.azizah@example.com'))) = 1, 'badge count is 1');

-- Respond rules.
select jt.expect_error(format($q$select contact_request_respond(%L, %L, true, '0812-3456')$q$, jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'r1')), 'not_target');
select jt.expect_error(format($q$select contact_request_respond(%L, %L, true, '   ')$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'r1')), 'shared_required');
select jt.expect_error(format($q$select contact_request_respond(%L, %L, true, %L)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'r1'), repeat('9', 201)), 'shared_too_long');
select jt.expect_error(format($q$select contact_request_respond(%L, gen_random_uuid(), true, 'x')$q$, jt.pid('siti.azizah@example.com')), 'not_found');

-- Nothing is released before accept.
select jt.expect_error(format($q$select contact_request_shared_contact(%L, %L)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'r1')), 'not_accepted');

-- Accept, with what the target types.
select contact_request_respond(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'r1'), true, 'WA 0812-3456-7890');
select jt.expect_error(format($q$select contact_request_respond(%L, %L, false, null)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'r1')), 'invalid_state');
select jt.assert((select status from contact_requests_outgoing(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'r1')) = 'accepted', 'requester sees accepted');
select jt.assert((select contact_request_shared_contact(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'r1'))) = 'WA 0812-3456-7890', 'requester gets the shared contact after accept');
select jt.expect_error(format($q$select contact_request_shared_contact(%L, %L)$q$, jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'r1')), 'not_requester');
select jt.expect_error(format($q$select contact_request_shared_contact(%L, %L)$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'r1')), 'not_requester');
-- The list functions still do not carry it.
select jt.assert((select count(*) from contact_requests_outgoing(jt.pid('ahmad.ramadhan@example.com')) o where to_jsonb(o)::text like '%0812%') = 0, 'outgoing list has no shared contact');
select jt.assert((select count(*) from contact_requests_incoming(jt.pid('siti.azizah@example.com')) o where to_jsonb(o)::text like '%0812%') = 0, 'incoming list has no shared contact');

-- Reject: requester only sees status rejected (the app says "not accepted").
select contact_request_respond(jt.pid('bagas.prasetyo@example.com'), (select v from t_ids where k = 'r_nomsg'), false, 'ignored text');
select jt.assert((select status from contact_requests_outgoing(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'r_nomsg')) = 'rejected', 'requester sees rejected');
select jt.expect_error(format($q$select contact_request_shared_contact(%L, %L)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'r_nomsg')), 'not_accepted');
select jt.assert((select count(*) from contact_requests_outgoing(jt.pid('ahmad.ramadhan@example.com')) o where to_jsonb(o)::text like '%ignored%') = 0, 'a rejection carries no text for the requester');
-- 30 day cool-down after a rejection.
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'sekali lagi')$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('bagas.prasetyo@example.com')), 'cooldown_active');
-- Others can still ask that person.
select contact_request_send(jt.pid('clara.putri@example.com'), jt.pid('bagas.prasetyo@example.com'), 'hai');
reset role;
-- 31 days later (simulated in the dashboard) it is allowed again.
update contact_requests set responded_at = now() - interval '31 days' where id = (select v from t_ids where k = 'r_nomsg');
set role anon;
select contact_request_send(jt.pid('ahmad.ramadhan@example.com'), jt.pid('bagas.prasetyo@example.com'), 'kali ini');
reset role;

-- Daily limit: 5 new requests per requester per day. Ahmad already sent 3
-- today (siti, bagas, bagas again).
set role anon;
select contact_request_send(jt.pid('ahmad.ramadhan@example.com'), jt.pid('clara.putri@example.com'), 'a');
with others as (
  select id from alumni_profiles where verification_status = 'verified'
    and email not in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com', 'clara.putri@example.com')
  order by email limit 2
)
select contact_request_send(jt.pid('ahmad.ramadhan@example.com'), id, 'b') from others limit 1;
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'c')$q$, jt.pid('ahmad.ramadhan@example.com'),
  (select id from alumni_profiles where verification_status = 'verified' and email not in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'bagas.prasetyo@example.com', 'clara.putri@example.com') order by email desc limit 1)), 'daily_limit_reached');
-- Another requester is not affected.
select contact_request_send(jt.pid('siti.azizah@example.com'), jt.pid('clara.putri@example.com'), 'hi');
reset role;

-- Dashboard can read and edit everything, shared_contact included.
select jt.assert((select shared_contact from contact_requests where id = (select v from t_ids where k = 'r1')) = 'WA 0812-3456-7890', 'dashboard can read shared_contact');

rollback;
\o
\echo contact request checks passed
