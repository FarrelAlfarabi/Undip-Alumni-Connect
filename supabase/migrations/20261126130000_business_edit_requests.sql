-- ============================================================================
-- Edit an approved business, with admin approval (26 Nov 2026).
--
-- An approved business is locked in the normal edit form. Now its owner can
-- ask for a change:
--   * The proposed values are stored in business_edit_requests. The business
--     row is NOT touched, so the old version stays visible to everyone until
--     an admin approves.
--   * One open ("pending") request per business. Sending again replaces the
--     values of the open one. The owner can cancel it.
--   * business_edit_request_my: the owner's own open request (and a request
--     turned down in the last 30 days, with the reason).
--   * admin_business_edit_requests: the list for admins, each row with the
--     current values next to the proposed ones (old vs new).
--   * admin_business_edit_decide: approve (the values are written to the
--     business) or reject (a reason is required). The owner gets a notice.
--   * A changed NIB loses its blue tick on approval (existing trigger), so
--     an admin checks it again with admin_business_nib_verify.
--   * The yearly sales band, status and owner cannot be changed this way.
--
-- Nobody gets direct table access: the table has RLS on and no grants. Every
-- function checks the caller (assert_caller for the owner, app_admin_assert
-- for admins).
-- Idempotent. Rollback: supabase/rollback_business_edit_requests.sql
-- ============================================================================

create table if not exists business_edit_requests (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  owner_id uuid not null references alumni_profiles (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 100),
  description text not null check (char_length(btrim(description)) between 1 and 500),
  category text not null,
  social_link text not null check (char_length(social_link) <= 300
    and social_link ~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$'),
  website_link text check (website_link is null or (char_length(website_link) <= 300
    and website_link ~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$')),
  is_personal boolean not null default false,
  nib text check (nib is null or nib ~ '^[0-9]{13}$'),
  photo_url text check (photo_url is null or (char_length(photo_url) <= 500
    and photo_url ~ '/object/public/business-photos/[^?#]+')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  reject_reason text check (reject_reason is null or char_length(reject_reason) <= 300),
  decided_by uuid,
  decided_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create unique index if not exists business_edit_requests_one_open
  on business_edit_requests (business_id) where status = 'pending';
create index if not exists idx_business_edit_requests_owner
  on business_edit_requests (owner_id, created_at desc);

alter table business_edit_requests enable row level security;
revoke all on business_edit_requests from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Owner: send (or resend) a change request for an approved business.
-- ---------------------------------------------------------------------------
create or replace function business_edit_request_submit(
  p_owner uuid,
  p_business uuid,
  p_name text,
  p_description text,
  p_category text,
  p_social_link text,
  p_website_link text,
  p_is_personal boolean,
  p_nib text,
  p_photo_url text
)
returns business_edit_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  b businesses;
  r business_edit_requests;
  v_name text := btrim(coalesce(p_name, ''));
  v_desc text := btrim(coalesce(p_description, ''));
  v_social text := nullif(btrim(coalesce(p_social_link, '')), '');
  v_web text := nullif(btrim(coalesce(p_website_link, '')), '');
  v_nib text := nullif(regexp_replace(coalesce(p_nib, ''), '[\s.\-]', '', 'g'), '');
  v_photo text := nullif(btrim(coalesce(p_photo_url, '')), '');
  v_personal boolean := coalesce(p_is_personal, false);
begin
  perform assert_caller(p_owner);
  -- Same gate as registering: verified and not suspended.
  if not business_is_verified(p_owner) then raise exception 'not_verified'; end if;
  select * into b from businesses where id = p_business for update;
  if not found then raise exception 'not_found'; end if;
  if b.owner_id <> p_owner then raise exception 'not_owner'; end if;
  if b.status <> 'approved' then raise exception 'locked'; end if;

  if char_length(v_name) < 2 or char_length(v_name) > 100
     or char_length(v_desc) < 1 or char_length(v_desc) > 500 then
    raise exception 'invalid_input';
  end if;
  -- A category has to be active, unless it is the one the business has now.
  if p_category is null
     or (p_category is distinct from b.category
         and not exists (select 1 from categories c where c.name = p_category and c.active)) then
    raise exception 'invalid_category';
  end if;
  if v_social is null then raise exception 'link_required'; end if;
  if v_social !~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$'
     or (v_web is not null and v_web !~* '^https?://[^/[:space:]]+\.[^/[:space:]]+(/[^[:space:]]*)?$')
     or char_length(v_social) > 300 or char_length(coalesce(v_web, '')) > 300 then
    raise exception 'invalid_link';
  end if;
  if v_nib is not null and v_nib !~ '^[0-9]{13}$' then raise exception 'invalid_nib'; end if;
  -- A new photo must be a file this owner uploaded to our own bucket
  -- (<host>/storage/v1/object/public/business-photos/<owner id>/...). The
  -- photo the business has now is always allowed.
  if v_photo is not null and v_photo is distinct from b.photo_url
     and (char_length(v_photo) > 500
          or v_photo !~ ('^https://[^/]+/storage/v1/object/public/business-photos/'
                         || p_owner::text || '/[^?#]+$')) then
    raise exception 'invalid_input';
  end if;

  -- Same rule as the business itself: a link belongs to one business only.
  if exists (
    select 1 from businesses o
    where o.id <> b.id
      and ((normalize_link(v_social) is not null
            and normalize_link(v_social) in (o.social_key, o.website_key))
        or (normalize_link(v_web) is not null
            and normalize_link(v_web) in (o.social_key, o.website_key)))
  ) then
    raise exception 'link_in_use';
  end if;

  if v_name = b.name and v_desc = b.description and p_category = b.category
     and v_social is not distinct from b.social_link
     and v_web is not distinct from b.website_link
     and v_personal = coalesce(b.is_personal, false)
     and v_nib is not distinct from b.nib
     and v_photo is not distinct from b.photo_url then
    raise exception 'no_change';
  end if;

  perform pg_advisory_xact_lock(hashtext('business_edit:' || b.id::text));
  select * into r from business_edit_requests
    where business_id = b.id and status = 'pending' for update;
  if found then
    update business_edit_requests set
      name = v_name, description = v_desc, category = p_category,
      social_link = v_social, website_link = v_web, is_personal = v_personal,
      nib = v_nib, photo_url = v_photo, updated_at = now()
    where id = r.id
    returning * into r;
  else
    insert into business_edit_requests
      (business_id, owner_id, name, description, category, social_link,
       website_link, is_personal, nib, photo_url)
    values
      (b.id, p_owner, v_name, v_desc, p_category, v_social, v_web, v_personal,
       v_nib, v_photo)
    returning * into r;
  end if;

  perform notify_admins(p_owner, 'business_edit_pending', 'Perubahan bisnis perlu ditinjau',
    '"' || b.name || '" meminta perubahan data.', 'business', b.id,
    'biz_edit_pending:' || r.id::text || ':' || notify_stamp());
  perform notify_create(p_owner, null, 'business_edit_received', 'Permintaan perubahan diterima',
    'Perubahan untuk "' || b.name || '" menunggu persetujuan admin. Data lama tetap tampil sampai disetujui.',
    'business', b.id, 'biz_edit_received:' || r.id::text || ':' || notify_stamp());
  return r;
end;
$$;

-- ---------------------------------------------------------------------------
-- Owner: cancel the open request.
-- ---------------------------------------------------------------------------
create or replace function business_edit_request_cancel(p_owner uuid, p_request uuid)
returns business_edit_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  r business_edit_requests;
begin
  perform assert_caller(p_owner);
  select * into r from business_edit_requests where id = p_request for update;
  if not found then raise exception 'not_found'; end if;
  if r.owner_id <> p_owner then raise exception 'not_owner'; end if;
  if r.status <> 'pending' then raise exception 'invalid_state'; end if;
  update business_edit_requests set status = 'cancelled', decided_at = now(), updated_at = now()
    where id = p_request returning * into r;
  return r;
end;
$$;

-- ---------------------------------------------------------------------------
-- Owner: my open request per business, and a rejected one from the last 30
-- days (with the reason). Only the latest request of each business counts.
-- ---------------------------------------------------------------------------
create or replace function business_edit_request_my(p_owner uuid)
returns setof business_edit_requests
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_owner);
  return query
    select l.id, l.business_id, l.owner_id, l.name, l.description, l.category,
           l.social_link, l.website_link, l.is_personal, l.nib, l.photo_url,
           l.status, l.reject_reason, null::uuid as decided_by, l.decided_at,
           l.created_at, l.updated_at
    from (
      select distinct on (r.business_id) r.*
      from business_edit_requests r
      where r.owner_id = p_owner
      order by r.business_id, r.created_at desc
    ) l
    where l.status = 'pending'
       or (l.status = 'rejected' and l.decided_at > now() - interval '30 days')
    order by l.created_at desc;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: the list, with the current values next to the proposed ones.
-- ---------------------------------------------------------------------------
create or replace function admin_business_edit_requests(p_admin uuid, p_status text default 'pending')
returns table (
  request_id uuid,
  business_id uuid,
  owner_id uuid,
  owner_name text,
  req_status text,
  reject_reason text,
  created_at timestamptz,
  decided_at timestamptz,
  new_name text,
  new_description text,
  new_category text,
  new_social_link text,
  new_website_link text,
  new_is_personal boolean,
  new_nib text,
  new_photo_url text,
  old_name text,
  old_description text,
  old_category text,
  old_social_link text,
  old_website_link text,
  old_is_personal boolean,
  old_nib text,
  old_photo_url text,
  old_nib_verified boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  if p_status is not null and p_status not in ('pending', 'approved', 'rejected', 'cancelled') then
    raise exception 'invalid_action';
  end if;
  return query
    select r.id, r.business_id, r.owner_id, p.name, r.status, r.reject_reason,
           r.created_at, r.decided_at,
           r.name, r.description, r.category, r.social_link, r.website_link,
           r.is_personal, r.nib, r.photo_url,
           b.name, b.description, b.category, b.social_link, b.website_link,
           coalesce(b.is_personal, false), b.nib, b.photo_url, b.nib_verified
    from business_edit_requests r
    join businesses b on b.id = r.business_id
    left join alumni_profiles p on p.id = r.owner_id
    where p_status is null or r.status = p_status
    order by (r.status = 'pending') desc, r.created_at desc
    limit 200;
end;
$$;

create or replace function admin_business_edit_pending_count(p_admin uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return (select count(*)::integer from business_edit_requests r where r.status = 'pending');
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: approve (writes the values to the business) or reject (reason).
-- ---------------------------------------------------------------------------
create or replace function admin_business_edit_decide(
  p_admin uuid,
  p_request uuid,
  p_action text,
  p_reason text default null
)
returns business_edit_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  r business_edit_requests;
  b businesses;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  perform app_admin_assert(p_admin);
  if p_action is null or p_action not in ('approve', 'reject') then
    raise exception 'invalid_action';
  end if;
  if char_length(coalesce(v_reason, '')) > 300 then raise exception 'reason_too_long'; end if;

  select * into r from business_edit_requests where id = p_request for update;
  if not found then raise exception 'not_found'; end if;
  if r.status <> 'pending' then raise exception 'invalid_state'; end if;

  if p_action = 'reject' then
    if v_reason is null then raise exception 'reason_required'; end if;
    update business_edit_requests set status = 'rejected', reject_reason = v_reason,
      decided_by = p_admin, decided_at = now(), updated_at = now()
    where id = p_request returning * into r;
    perform notify_create(r.owner_id, p_admin, 'business_edit_rejected', 'Perubahan bisnis ditolak',
      'Perubahan untuk "' || r.name || '" ditolak. Alasan: ' || v_reason || '. Data lama tetap tampil.',
      'business', r.business_id, 'biz_edit_rejected:' || r.id::text);
    return r;
  end if;

  select * into b from businesses where id = r.business_id for update;
  if not found then raise exception 'not_found'; end if;
  if b.status <> 'approved' then raise exception 'invalid_state'; end if;

  -- Only these columns. The band, status and owner are never touched. A
  -- changed NIB loses its tick (trigger trg_businesses_nib_reset); a link
  -- another business took in the meantime is refused (businesses_prepare).
  update businesses set
    name = r.name,
    description = r.description,
    category = r.category,
    social_link = r.social_link,
    website_link = r.website_link,
    is_personal = r.is_personal,
    nib = r.nib,
    photo_url = r.photo_url
  where id = b.id;

  update business_edit_requests set status = 'approved',
    decided_by = p_admin, decided_at = now(), updated_at = now()
  where id = p_request returning * into r;
  perform notify_create(r.owner_id, p_admin, 'business_edit_approved', 'Perubahan bisnis disetujui',
    'Perubahan untuk "' || r.name || '" disetujui dan sudah tampil.'
      || case when r.nib is distinct from b.nib and r.nib is not null
              then ' NIB baru akan dicek admin untuk tanda centang biru.' else '' end,
    'business', r.business_id, 'biz_edit_approved:' || r.id::text);
  return r;
end;
$$;

revoke execute on function business_edit_request_submit(uuid, uuid, text, text, text, text, text, boolean, text, text) from public;
revoke execute on function business_edit_request_cancel(uuid, uuid) from public;
revoke execute on function business_edit_request_my(uuid) from public;
revoke execute on function admin_business_edit_requests(uuid, text) from public;
revoke execute on function admin_business_edit_pending_count(uuid) from public;
revoke execute on function admin_business_edit_decide(uuid, uuid, text, text) from public;
grant execute on function business_edit_request_submit(uuid, uuid, text, text, text, text, text, boolean, text, text) to anon, authenticated;
grant execute on function business_edit_request_cancel(uuid, uuid) to anon, authenticated;
grant execute on function business_edit_request_my(uuid) to anon, authenticated;
grant execute on function admin_business_edit_requests(uuid, text) to anon, authenticated;
grant execute on function admin_business_edit_pending_count(uuid) to anon, authenticated;
grant execute on function admin_business_edit_decide(uuid, uuid, text, text) to anon, authenticated;
