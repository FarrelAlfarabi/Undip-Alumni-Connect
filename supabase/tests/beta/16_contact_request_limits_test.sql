-- Contact request limits: open-request cap and no re-ask after an accept.
-- (5 per day, one open per pair and the 30 day cool-down are in 04.)
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified';

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

-- Accepted: the requester already has the contact, so no new request.
set role anon;
insert into t_ids select 'r1', id from contact_request_send(jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com'), 'hai');
select contact_request_respond(jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'r1'), true, 'WA 0812');
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'lagi')$q$, jt.pid('ahmad.ramadhan@example.com'), jt.pid('siti.azizah@example.com')), 'already_shared');
-- The other direction is a different pair and still works.
select contact_request_send(jt.pid('siti.azizah@example.com'), jt.pid('ahmad.ramadhan@example.com'), 'balik');
reset role;

-- Open cap: 10 pending per requester. Fill the quota from the dashboard
-- (no daily limit there), then try through the app role.
insert into contact_requests (requester_id, target_id)
select jt.pid('ahmad.ramadhan@example.com'), id
from alumni_profiles
where id <> jt.pid('ahmad.ramadhan@example.com') and id <> jt.pid('siti.azizah@example.com')
order by email limit 10;
select jt.assert((select count(*) from contact_requests where requester_id = jt.pid('ahmad.ramadhan@example.com') and status = 'pending') = 10, 'ahmad has 10 open requests');
-- Make the daily limit not the reason for the refusal.
update contact_requests set created_at = now() - interval '3 days' where requester_id = jt.pid('ahmad.ramadhan@example.com');

-- Pick two targets ahmad has not asked yet (as dashboard, anon cannot read the table).
insert into t_ids select 'free1', id from alumni_profiles
  where id <> jt.pid('ahmad.ramadhan@example.com')
    and id not in (select target_id from contact_requests where requester_id = jt.pid('ahmad.ramadhan@example.com'))
  order by email limit 1;
insert into t_ids select 'free2', id from alumni_profiles
  where id <> jt.pid('ahmad.ramadhan@example.com')
    and id not in (select target_id from contact_requests where requester_id = jt.pid('ahmad.ramadhan@example.com'))
    and id <> (select v from t_ids where k = 'free1')
  order by email limit 1;

set role anon;
select jt.expect_error(format($q$select contact_request_send(%L, %L, 'x')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'free1')), 'too_many_open');
reset role;

-- One answer frees a slot.
update contact_requests set status = 'rejected', responded_at = now()
  where id = (select id from contact_requests where requester_id = jt.pid('ahmad.ramadhan@example.com') and status = 'pending' limit 1);
set role anon;
select contact_request_send(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'free1'), 'ok');
reset role;

rollback;
\o
\echo contact request limit checks passed
