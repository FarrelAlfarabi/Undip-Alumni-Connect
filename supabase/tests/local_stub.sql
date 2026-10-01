-- Minimal stand-in for the parts of Supabase the migrations depend on, so
-- the SQL can be tested on a plain local Postgres. NOT a full Supabase: no
-- PostgREST, no real auth. Approximates Supabase's default privileges.
-- Roles are cluster-wide, so tolerate a second database on the same cluster.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;

create schema if not exists extensions;
grant usage on schema extensions to anon, authenticated, service_role;

create schema auth;
create table auth.users (id uuid primary key default gen_random_uuid());
create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;

create schema storage;
create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text
);
alter table storage.objects enable row level security;
create function storage.extension(name text) returns text language sql immutable as $$
  select case when position('.' in name) > 0
    then substring(name from '[^.]*$') else '' end
$$;

-- Supabase grants anon/authenticated broad default privileges in public;
-- RLS is what restricts them. Mirror that so tests exercise RLS for real.
grant usage on schema public, auth, storage to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
grant all on all tables in schema storage to anon, authenticated, service_role;
