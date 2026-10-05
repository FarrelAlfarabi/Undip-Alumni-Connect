-- ============================================================================
-- Business directory (closed beta, Stage 5).
--
-- An alumnus registers a business: name, short description, category, a
-- social link and/or a website link, and a yearly sales band. Status starts
-- as 'pending'. Only approved businesses are shown to other people.
--
-- Bands follow the official Indonesian UMKM definition (PP 7/2021, Art. 35):
--   micro   up to Rp 2 miliar a year
--   small   over Rp 2 miliar up to Rp 15 miliar
--   medium  over Rp 15 miliar up to Rp 50 miliar
--   large   over Rp 50 miliar (not UMKM)
-- The owner declares requested_band once. approved_band is set by an admin
-- (or the dashboard) only.
--
-- ACCESS MODEL: no direct table access for the app (anon / authenticated).
-- Everything goes through the SECURITY DEFINER functions below, in the same
-- style as the marketplace. A column-lock trigger stays as a second guard
-- (it makes status, approved_band, unlimited_until, rejection_reason,
-- requested_band and owner_id un-editable for anon/authenticated even if a
-- table grant is added by mistake). The dashboard (postgres / service_role)
-- can view and edit everything.
--
-- HONEST LIMIT: the app has no real login. The owner / viewer id passed to
-- these functions is NOT authenticated, so they stop mistakes and casual
-- abuse, not someone who deliberately passes another person's profile id.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_business_directory.sql
-- ============================================================================

create table if not exists businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references alumni_profiles (id),
  name text not null check (char_length(btrim(name)) between 2 and 100),
  description text not null check (char_length(btrim(description)) between 1 and 500),
  category text not null
    check (category in ('Food & Drink', 'Fashion', 'Electronics', 'Services', 'Other')),
  social_link text check (social_link is null or (char_length(social_link) <= 300 and social_link ~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$')),
  website_link text check (website_link is null or (char_length(website_link) <= 300 and website_link ~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$')),
  -- Cleaned-up copies of the links, filled by a trigger. Used to catch the
  -- same link written differently (case, www, query string, trailing slash).
  social_key text,
  website_key text,
  requested_band text not null check (requested_band in ('micro', 'small', 'medium', 'large')),
  approved_band text check (approved_band is null or approved_band in ('micro', 'small', 'medium', 'large')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'suspended')),
  rejection_reason text check (rejection_reason is null or char_length(rejection_reason) <= 300),
  -- Unlimited product posting until this date (inclusive). Dashboard only.
  unlimited_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint businesses_has_link check (social_link is not null or website_link is not null)
);

create index if not exists idx_businesses_owner on businesses (owner_id);
create index if not exists idx_businesses_status on businesses (status);
create unique index if not exists businesses_social_key_uq on businesses (social_key) where social_key is not null;
create unique index if not exists businesses_website_key_uq on businesses (website_key) where website_key is not null;

alter table businesses enable row level security;
revoke all on businesses from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Link cleaning: lower case, no scheme, no "www.", no query or fragment, no
-- trailing slash.
-- ---------------------------------------------------------------------------
create or replace function normalize_link(p_link text)
returns text
language sql
immutable
set search_path = public
as $$
  select nullif(
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(lower(btrim(coalesce(p_link, ''))), '^https?://', ''),
          '^www\.', ''),
        '[?#].*$', ''),
      '/+$', ''),
    '');
$$;

-- ---------------------------------------------------------------------------
-- Trigger 1 (SECURITY DEFINER): fill the cleaned links, refuse a link that
-- another business already uses (in either link column), keep updated_at.
-- ---------------------------------------------------------------------------
create or replace function businesses_prepare()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.social_key := normalize_link(new.social_link);
  new.website_key := normalize_link(new.website_link);

  -- Serialise registrations so two people cannot claim one link at once.
  perform pg_advisory_xact_lock(hashtext('businesses_links'));

  if exists (
    select 1 from businesses b
    where b.id <> new.id
      and (
        (new.social_key is not null and new.social_key in (b.social_key, b.website_key))
        or (new.website_key is not null and new.website_key in (b.social_key, b.website_key))
      )
  ) then
    raise exception 'link_in_use';
  end if;

  if tg_op = 'UPDATE' then new.updated_at := now(); end if;
  return new;
end;
$$;
revoke execute on function businesses_prepare() from public, anon, authenticated;

drop trigger if exists businesses_prepare_trigger on businesses;
create trigger businesses_prepare_trigger
  before insert or update on businesses
  for each row execute function businesses_prepare();

-- ---------------------------------------------------------------------------
-- Trigger 2 (SECURITY INVOKER on purpose, like alumni_profiles_restrict_update):
-- for anon / authenticated, status, approved_band, unlimited_until,
-- rejection_reason, requested_band and owner_id cannot be set or changed.
-- The SECURITY DEFINER functions below run as the owner, so they pass.
-- ---------------------------------------------------------------------------
create or replace function businesses_lock_columns()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'pending'
       or new.approved_band is not null
       or new.unlimited_until is not null
       or new.rejection_reason is not null then
      raise exception 'locked_column';
    end if;
  else
    if new.id <> old.id
       or new.owner_id <> old.owner_id
       or new.status <> old.status
       or new.approved_band is distinct from old.approved_band
       or new.unlimited_until is distinct from old.unlimited_until
       or new.rejection_reason is distinct from old.rejection_reason
       or new.requested_band <> old.requested_band
       or new.created_at <> old.created_at then
      raise exception 'locked_column';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function businesses_lock_columns() from public, anon, authenticated;

drop trigger if exists businesses_lock_columns_trigger on businesses;
create trigger businesses_lock_columns_trigger
  before insert or update on businesses
  for each row execute function businesses_lock_columns();

-- ---------------------------------------------------------------------------
-- Functions the app calls
-- ---------------------------------------------------------------------------
create or replace function business_is_verified(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from alumni_profiles
    where id = p_profile and verification_status = 'verified'
  );
$$;
revoke execute on function business_is_verified(uuid) from public, anon, authenticated;

-- Register. Always 'pending', no approved band, no unlimited date.
create or replace function business_register(
  p_owner uuid,
  p_name text,
  p_description text,
  p_category text,
  p_social_link text,
  p_website_link text,
  p_band text
)
returns businesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v businesses;
  v_social text := nullif(btrim(coalesce(p_social_link, '')), '');
  v_web text := nullif(btrim(coalesce(p_website_link, '')), '');
begin
  if not business_is_verified(p_owner) then raise exception 'not_verified'; end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2
     or char_length(btrim(coalesce(p_name, ''))) > 100
     or char_length(btrim(coalesce(p_description, ''))) < 1
     or char_length(btrim(coalesce(p_description, ''))) > 500 then
    raise exception 'invalid_input';
  end if;
  if p_category is null or p_category not in ('Food & Drink', 'Fashion', 'Electronics', 'Services', 'Other') then
    raise exception 'invalid_category';
  end if;
  if p_band is null or p_band not in ('micro', 'small', 'medium', 'large') then
    raise exception 'invalid_band';
  end if;
  if v_social is null and v_web is null then raise exception 'link_required'; end if;
  if (v_social is not null and v_social !~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$')
     or (v_web is not null and v_web !~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$')
     or char_length(coalesce(v_social, '')) > 300 or char_length(coalesce(v_web, '')) > 300 then
    raise exception 'invalid_link';
  end if;

  insert into businesses
    (owner_id, name, description, category, social_link, website_link, requested_band, status)
  values
    (p_owner, btrim(p_name), btrim(p_description), p_category, v_social, v_web, p_band, 'pending')
  returning * into v;
  return v;
end;
$$;

-- Owner edits. Only while pending or rejected. A rejected business goes
-- back to pending (apply again). The band is never changed here.
create or replace function business_update(
  p_owner uuid,
  p_business uuid,
  p_name text,
  p_description text,
  p_category text,
  p_social_link text,
  p_website_link text
)
returns businesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v businesses;
  v_social text := nullif(btrim(coalesce(p_social_link, '')), '');
  v_web text := nullif(btrim(coalesce(p_website_link, '')), '');
begin
  select * into v from businesses where id = p_business for update;
  if not found then raise exception 'not_found'; end if;
  if v.owner_id <> p_owner then raise exception 'not_owner'; end if;
  if v.status not in ('pending', 'rejected') then raise exception 'locked'; end if;

  if char_length(btrim(coalesce(p_name, ''))) < 2
     or char_length(btrim(coalesce(p_name, ''))) > 100
     or char_length(btrim(coalesce(p_description, ''))) < 1
     or char_length(btrim(coalesce(p_description, ''))) > 500 then
    raise exception 'invalid_input';
  end if;
  if p_category is null or p_category not in ('Food & Drink', 'Fashion', 'Electronics', 'Services', 'Other') then
    raise exception 'invalid_category';
  end if;
  if v_social is null and v_web is null then raise exception 'link_required'; end if;
  if (v_social is not null and v_social !~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$')
     or (v_web is not null and v_web !~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$')
     or char_length(coalesce(v_social, '')) > 300 or char_length(coalesce(v_web, '')) > 300 then
    raise exception 'invalid_link';
  end if;

  update businesses set
    name = btrim(p_name),
    description = btrim(p_description),
    category = p_category,
    social_link = v_social,
    website_link = v_web,
    status = 'pending',
    rejection_reason = null
  where id = p_business
  returning * into v;
  return v;
end;
$$;

-- The owner's own businesses, every status, with rejection reason, approved
-- band and unlimited_until.
create or replace function business_my(p_owner uuid)
returns setof businesses
language sql
stable
security definer
set search_path = public
as $$
  select * from businesses where owner_id = p_owner order by created_at desc;
$$;

-- The directory: approved businesses, for verified alumni only.
create or replace function business_directory(p_viewer uuid)
returns table (
  id uuid,
  owner_id uuid,
  name text,
  description text,
  category text,
  social_link text,
  website_link text,
  approved_band text,
  created_at timestamptz,
  owner_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not business_is_verified(p_viewer) then raise exception 'not_verified'; end if;
  return query
    select b.id, b.owner_id, b.name, b.description, b.category, b.social_link,
           b.website_link, b.approved_band, b.created_at, p.name
    from businesses b
    join alumni_profiles p on p.id = b.owner_id
    where b.status = 'approved'
    order by b.name asc;
end;
$$;

revoke execute on function normalize_link(text) from public, anon, authenticated;
revoke execute on function business_register(uuid, text, text, text, text, text, text) from public;
revoke execute on function business_update(uuid, uuid, text, text, text, text, text) from public;
revoke execute on function business_my(uuid) from public;
revoke execute on function business_directory(uuid) from public;
grant execute on function business_register(uuid, text, text, text, text, text, text) to anon, authenticated;
grant execute on function business_update(uuid, uuid, text, text, text, text, text) to anon, authenticated;
grant execute on function business_my(uuid) to anon, authenticated;
grant execute on function business_directory(uuid) to anon, authenticated;
