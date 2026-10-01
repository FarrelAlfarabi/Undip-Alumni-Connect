-- Job posting gate + demo_subscribe checks. Run through run_local.sh after
-- the migrations and seed.sql. Roles are simulated with `set role anon`, as
-- the app only ever calls Postgres as anon. A failure raises and stops.

\set ON_ERROR_STOP on
\o /dev/null

create schema jt;
create function jt.assert(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is not true then raise exception 'ASSERT FAILED: %', msg; end if;
end $$;
create function jt.expect_error(p_sql text, p_pattern text) returns void language plpgsql as $$
declare ok boolean := false;
begin
  begin
    execute p_sql;
    ok := true;
  exception when others then
    if sqlerrm !~ p_pattern then
      raise exception 'ASSERT FAILED: expected error ~ "%" but got "%" for: %', p_pattern, sqlerrm, p_sql;
    end if;
  end;
  if ok then raise exception 'ASSERT FAILED: expected error ~ "%" but statement succeeded: %', p_pattern, p_sql; end if;
end $$;
create function jt.pid(p_email text) returns uuid language sql stable as $$
  select id from public.alumni_profiles where email = p_email $$;
grant usage on schema jt to public;

-- Fixtures (postgres role): ahmad = free, siti = subscribed.
update alumni_profiles set subscription_status = 'free' where email = 'ahmad.ramadhan@example.com';
update alumni_profiles set subscription_status = 'subscribed' where email = 'siti.azizah@example.com';

set role anon;

-- Free poster, no poster, and unknown poster are refused.
select jt.expect_error(format($q$insert into job_posts (posted_by, title, company, description) values (%L, 't', 'c', 'd')$q$, jt.pid('ahmad.ramadhan@example.com')), 'subscriber_required');
select jt.expect_error($q$insert into job_posts (posted_by, title, company, description) values (null, 't', 'c', 'd')$q$, 'subscriber_required');
select jt.expect_error($q$insert into job_posts (posted_by, title, company, description) values (gen_random_uuid(), 't', 'c', 'd')$q$, 'subscriber_required');

-- Subscribed poster is accepted.
insert into job_posts (posted_by, title, company, description)
  values (jt.pid('siti.azizah@example.com'), 'gate ok', 'c', 'd');

-- A plain UPDATE can no longer change subscription_status ...
select jt.expect_error(format($q$update alumni_profiles set subscription_status = 'subscribed' where id = %L$q$, jt.pid('ahmad.ramadhan@example.com')), 'subscription_status can only be changed');
-- ... but the fields the app still edits keep working.
update alumni_profiles set industry = 'Technology' where id = jt.pid('ahmad.ramadhan@example.com');

-- demo_subscribe works while demo mode is on, then the free poster can post.
select jt.assert((select subscription_status from demo_subscribe(jt.pid('ahmad.ramadhan@example.com'))) = 'subscribed', 'demo_subscribe returns the subscribed row');
insert into job_posts (posted_by, title, company, description)
  values (jt.pid('ahmad.ramadhan@example.com'), 'gate ok 2', 'c', 'd');
select jt.expect_error($q$select demo_subscribe(gen_random_uuid())$q$, 'not_found');

-- anon cannot read or write the kill switch.
select jt.expect_error($q$select * from billing_settings$q$, 'permission denied');
select jt.expect_error($q$update billing_settings set demo_subscriptions = false$q$, 'permission denied');

reset role;

-- Dashboard / owner is exempt, so seed files and admin edits still work.
insert into job_posts (posted_by, title, company, description)
  values (null, 'owner insert', 'c', 'd');
update billing_settings set demo_subscriptions = false;
update alumni_profiles set subscription_status = 'free' where email = 'ahmad.ramadhan@example.com';

-- With demo mode off, the app cannot subscribe anyone any more.
set role anon;
select jt.expect_error(format($q$select demo_subscribe(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'demo_subscriptions_disabled');
select jt.expect_error(format($q$insert into job_posts (posted_by, title, company, description) values (%L, 't', 'c', 'd')$q$, jt.pid('ahmad.ramadhan@example.com')), 'subscriber_required');
reset role;

-- Put the database back the way the other tests expect it.
update billing_settings set demo_subscriptions = true;
delete from job_posts where title in ('gate ok', 'gate ok 2', 'owner insert');
drop schema jt cascade;
\o
\echo job posting gate checks passed
