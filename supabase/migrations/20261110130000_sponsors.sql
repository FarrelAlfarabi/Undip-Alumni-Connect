-- ============================================================================
-- Sponsors: a carousel under the four tiles on Home.
--
-- sponsors: members read only the LIVE rows (active, and today in Jakarta is
-- inside starts_on..ends_on, either may be empty). NO insert/update/delete
-- policy exists, so the app roles cannot write the table. Admins write through
-- SECURITY DEFINER functions that check app_admins (app_admin_assert), and
-- Farrel can edit the table in the Supabase dashboard at any time.
-- home_sponsors() gives the app the live rows in carousel order (rank, then
-- oldest first). More than one sponsor can be live at the same time.
--
-- Rules (invalid_input): name 1 to 80 characters; link starts with https://
-- (500 characters at most, no spaces); image link points to the
-- sponsor-images bucket on a supabase.co host (no outside image hosts);
-- ends_on is not before starts_on; rank 0 to 999.
--
-- Storage bucket sponsor-images: public, 2 MB, images only. Same open upload
-- model as avatars and job-photos (the app has no Supabase Auth session on
-- upload). A file only shows up in the app when an admin saves its link on a
-- sponsor, and there is no list policy, so nobody can browse the bucket.
--
-- Idempotent. Rollback: supabase/rollback_sponsors.sql
-- ============================================================================

create table if not exists sponsors (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  image_url text not null
    check (image_url ~ '^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/public/sponsor-images/[^?#]+$'),
  link_url text not null
    check (link_url ~ '^https://[^[:space:][:cntrl:]]+$' and char_length(link_url) <= 500),
  starts_on date,
  ends_on date,
  rank integer not null default 1 check (rank between 0 and 999),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  check (starts_on is null or ends_on is null or ends_on >= starts_on)
);

alter table sponsors enable row level security;
revoke all on sponsors from public, anon, authenticated;
grant select on sponsors to anon, authenticated;

drop policy if exists sponsors_read_live on sponsors;
create policy sponsors_read_live on sponsors
  for select to anon, authenticated using (
    active
    and (starts_on is null or starts_on <= (now() at time zone 'Asia/Jakarta')::date)
    and (ends_on is null or ends_on >= (now() at time zone 'Asia/Jakarta')::date)
  );

create or replace function home_sponsors()
returns table (id uuid, name text, image_url text, link_url text)
language sql
stable
set search_path = public
as $$
  select s.id, s.name, s.image_url, s.link_url
  from sponsors s
  order by s.rank, s.created_at, s.id;
$$;

create or replace function admin_sponsor_list(p_admin uuid)
returns table (
  id uuid, name text, image_url text, link_url text,
  starts_on date, ends_on date, rank integer, active boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select s.id, s.name, s.image_url, s.link_url,
           s.starts_on, s.ends_on, s.rank, s.active
    from sponsors s
    order by s.rank, s.created_at, s.id;
end;
$$;

-- p_id null adds a row, otherwise changes that row (not_found if it is gone).
create or replace function admin_sponsor_save(
  p_admin uuid,
  p_id uuid,
  p_name text,
  p_image_url text,
  p_link_url text,
  p_starts_on date,
  p_ends_on date,
  p_rank integer,
  p_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p_name, ''), E' \t\r\n');
  v_image text := btrim(coalesce(p_image_url, ''), E' \t\r\n');
  v_link text := btrim(coalesce(p_link_url, ''), E' \t\r\n');
  v_rank integer := coalesce(p_rank, 1);
  v_id uuid;
begin
  perform app_admin_assert(p_admin);
  if v_name = '' or char_length(v_name) > 80
     or v_image !~ '^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/public/sponsor-images/[^?#]+$'
     or v_link !~ '^https://[^[:space:][:cntrl:]]+$' or char_length(v_link) > 500
     or v_rank < 0 or v_rank > 999
     or (p_starts_on is not null and p_ends_on is not null and p_ends_on < p_starts_on) then
    raise exception 'invalid_input';
  end if;
  if p_id is null then
    insert into sponsors (name, image_url, link_url, starts_on, ends_on, rank, active)
      values (v_name, v_image, v_link, p_starts_on, p_ends_on, v_rank, coalesce(p_active, true))
      returning sponsors.id into v_id;
    return v_id;
  end if;
  update sponsors
     set name = v_name, image_url = v_image, link_url = v_link,
         starts_on = p_starts_on, ends_on = p_ends_on,
         rank = v_rank, active = coalesce(p_active, true)
   where sponsors.id = p_id
   returning sponsors.id into v_id;
  if v_id is null then raise exception 'not_found'; end if;
  return v_id;
end;
$$;

create or replace function admin_sponsor_delete(p_admin uuid, p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  delete from sponsors where id = p_id;
  if not found then raise exception 'not_found'; end if;
end;
$$;

revoke execute on function home_sponsors() from public;
revoke execute on function admin_sponsor_list(uuid) from public;
revoke execute on function admin_sponsor_save(uuid, uuid, text, text, text, date, date, integer, boolean) from public;
revoke execute on function admin_sponsor_delete(uuid, uuid) from public;
grant execute on function home_sponsors() to anon, authenticated;
grant execute on function admin_sponsor_list(uuid) to anon, authenticated;
grant execute on function admin_sponsor_save(uuid, uuid, text, text, text, date, date, integer, boolean) to anon, authenticated;
grant execute on function admin_sponsor_delete(uuid, uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Storage bucket
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'sponsor-images', 'sponsor-images', true, 2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "sponsor_images_public_upload" on storage.objects;
create policy "sponsor_images_public_upload" on storage.objects
  for insert with check (
    bucket_id = 'sponsor-images'
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );
