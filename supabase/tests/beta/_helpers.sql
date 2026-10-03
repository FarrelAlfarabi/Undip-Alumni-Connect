-- Shared helpers for the beta SQL tests. Created and dropped by
-- run_beta_local.sh. Roles are simulated with `set role anon`, as the app
-- only ever calls Postgres as anon.
create schema if not exists jt;
create or replace function jt.assert(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is not true then raise exception 'ASSERT FAILED: %', msg; end if;
end $$;
create or replace function jt.expect_error(p_sql text, p_pattern text) returns void language plpgsql as $$
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
create or replace function jt.pid(p_email text) returns uuid language sql stable as $$
  select id from public.alumni_profiles where email = p_email $$;
-- Row count the caller (current role) can see.
create or replace function jt.count_of(p_sql text) returns bigint language plpgsql as $$
declare n bigint;
begin execute 'select count(*) from (' || p_sql || ') q' into n; return n; end $$;
grant usage on schema jt to public;
grant execute on all functions in schema jt to public;
