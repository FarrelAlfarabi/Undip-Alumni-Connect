-- ============================================================================
-- Optional NIB on a business, with a blue tick after an admin checks it
-- (10 Nov 2026).
--
--   * businesses.nib: 13 digits, optional. The owner types it.
--   * businesses.nib_verified (+ _at, _by): set ONLY by an admin, through
--     admin_business_nib_verify(). Owners and the app cannot set it: the
--     table has no grants for anon/authenticated, business_register /
--     business_update / business_set_nib never touch the flag, and a trigger
--     takes the flag away whenever the number changes.
--   * business_set_nib: the owner adds, changes or clears the NIB. Allowed
--     while the business is pending, approved or rejected (an approved
--     business is locked in the form, but must still be able to add a NIB
--     later). Not when suspended.
--   * business_nib_verified_ids: ids of directory businesses with a checked
--     NIB. business_directory() is left as it is (older app builds), the app
--     reads the ids with this call, like the photos. The NIB number itself is
--     never returned to other alumni.
--   * admin_business_nibs / admin_business_nib_verify: admin only.
--
-- Idempotent. Rollback: supabase/rollback_business_nib.sql
-- ============================================================================

alter table businesses add column if not exists nib text;
alter table businesses add column if not exists nib_verified boolean not null default false;
alter table businesses add column if not exists nib_verified_at timestamptz;
alter table businesses add column if not exists nib_verified_by uuid;

alter table businesses drop constraint if exists businesses_nib_format;
alter table businesses add constraint businesses_nib_format
  check (nib is null or nib ~ '^[0-9]{13}$');

-- A tick without a number makes no sense.
alter table businesses drop constraint if exists businesses_nib_verified_needs_nib;
alter table businesses add constraint businesses_nib_verified_needs_nib
  check (not nib_verified or nib is not null);

-- ---------------------------------------------------------------------------
-- A changed number loses its tick. If the same update sets the flag itself
-- (an admin function or the dashboard), the flag is left as written.
-- ---------------------------------------------------------------------------
create or replace function businesses_nib_reset()
returns trigger
language plpgsql
as $$
begin
  if new.nib is distinct from old.nib
     and new.nib_verified is not distinct from old.nib_verified then
    new.nib_verified := false;
    new.nib_verified_at := null;
    new.nib_verified_by := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_businesses_nib_reset on businesses;
create trigger trg_businesses_nib_reset
  before update of nib on businesses
  for each row execute function businesses_nib_reset();

-- ---------------------------------------------------------------------------
-- Owner: add, change or clear the NIB.
-- ---------------------------------------------------------------------------
create or replace function business_set_nib(
  p_owner uuid,
  p_business uuid,
  p_nib text
)
returns businesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v businesses;
  v_nib text := nullif(regexp_replace(coalesce(p_nib, ''), '[\s.\-]', '', 'g'), '');
begin
  perform assert_caller(p_owner);
  select * into v from businesses where id = p_business for update;
  if not found then raise exception 'not_found'; end if;
  if v.owner_id <> p_owner then raise exception 'not_owner'; end if;
  if v.status not in ('pending', 'approved', 'rejected') then raise exception 'locked'; end if;
  if v_nib is not null and v_nib !~ '^[0-9]{13}$' then raise exception 'invalid_nib'; end if;

  -- Only the number is written. The trigger drops the tick if it changed.
  update businesses set nib = v_nib where id = p_business
  returning * into v;
  return v;
end;
$$;

-- ---------------------------------------------------------------------------
-- Alumni: which directory businesses have a checked NIB (ids only).
-- ---------------------------------------------------------------------------
create or replace function business_nib_verified_ids(p_viewer uuid)
returns table (business_id uuid)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_viewer);
  if not business_is_verified(p_viewer) then raise exception 'not_verified'; end if;
  return query
    select b.id
    from businesses b
    where b.status = 'approved' and b.hidden_at is null and b.nib_verified;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: see every NIB, mark one as checked, or take the mark away.
-- ---------------------------------------------------------------------------
create or replace function admin_business_nibs(p_admin uuid)
returns table (business_id uuid, nib text, nib_verified boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select b.id, b.nib, b.nib_verified from businesses b where b.nib is not null;
end;
$$;

create or replace function admin_business_nib_verify(
  p_admin uuid,
  p_business uuid,
  p_verified boolean
)
returns businesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v businesses;
begin
  perform app_admin_assert(p_admin);
  if p_verified is null then raise exception 'invalid_input'; end if;
  select * into v from businesses where id = p_business for update;
  if not found then raise exception 'not_found'; end if;
  if p_verified and v.nib is null then raise exception 'nib_required'; end if;

  update businesses set
    nib_verified = p_verified,
    nib_verified_at = case when p_verified then now() else null end,
    nib_verified_by = case when p_verified then p_admin else null end
  where id = p_business
  returning * into v;
  return v;
end;
$$;

revoke execute on function businesses_nib_reset() from public, anon, authenticated;
revoke execute on function business_set_nib(uuid, uuid, text) from public;
revoke execute on function business_nib_verified_ids(uuid) from public;
revoke execute on function admin_business_nibs(uuid) from public;
revoke execute on function admin_business_nib_verify(uuid, uuid, boolean) from public;
grant execute on function business_set_nib(uuid, uuid, text) to anon, authenticated;
grant execute on function business_nib_verified_ids(uuid) to anon, authenticated;
grant execute on function admin_business_nibs(uuid) to anon, authenticated;
grant execute on function admin_business_nib_verify(uuid, uuid, boolean) to anon, authenticated;
