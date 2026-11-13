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
create or replace function jt.pid(p_email text) returns uuid language sql stable security definer as $$
  select id from public.alumni_profiles where email = p_email $$;
-- Row count the caller (current role) can see.
create or replace function jt.count_of(p_sql text) returns bigint language plpgsql as $$
declare n bigint;
begin execute 'select count(*) from (' || p_sql || ') q' into n; return n; end $$;
grant usage on schema jt to public;
grant execute on all functions in schema jt to public;
-- The tests act as the app user through the anon role. Since 20261113100000
-- anon cannot read alumni_profiles; the runner gives it back (all columns but
-- nim) for every test except 24_*, which checks the real state.
create or replace function jt.anon_reads_profiles(p_on boolean) returns void language plpgsql as $$
declare cols text;
begin
  select string_agg(quote_ident(column_name), ', ') into cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'alumni_profiles' and column_name <> 'nim';
  if p_on then
    execute 'grant select (' || cols || ') on public.alumni_profiles to anon';
  else
    execute 'revoke select on public.alumni_profiles from anon';
    execute 'revoke select (' || cols || ', nim) on public.alumni_profiles from anon';
  end if;
end $$;
