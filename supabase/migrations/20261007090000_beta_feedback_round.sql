-- ============================================================================
-- Beta feedback round (7 Oct 2026).
--
--   1. Personal business: businesses.is_personal (a business run by one
--      person). Set when registering or editing a pending/rejected business.
--   2. At most 3 businesses per owner (rejected ones do not count). More must
--      be requested by email; the app shows the contact email.
--   3. Admins: count of reports they have not seen yet, and a call that marks
--      them seen. Marketplace reports are counted together with the others.
--
-- business_register / business_update are dropped and recreated with the new
-- parameter (it has a default, so old positional calls still work). The
-- directory and admin list keep their old return shape on purpose.
-- Idempotent. Rollback: supabase/rollback_beta_feedback_round.sql
-- ============================================================================

alter table businesses add column if not exists is_personal boolean not null default false;

-- ------------------------------------------------------- register / update ---
drop function if exists business_register(uuid, text, text, text, text, text, text);
create or replace function business_register(
  p_owner uuid,
  p_name text,
  p_description text,
  p_category text,
  p_social_link text,
  p_website_link text,
  p_band text,
  p_personal boolean default false
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

  -- Serialise per owner so two taps cannot slip past the limit.
  perform pg_advisory_xact_lock(hashtext('business_owner:' || p_owner::text));
  if (select count(*) from businesses where owner_id = p_owner and status <> 'rejected') >= 3 then
    raise exception 'business_limit';
  end if;

  insert into businesses
    (owner_id, name, description, category, social_link, website_link, requested_band, status, is_personal)
  values
    (p_owner, btrim(p_name), btrim(p_description), p_category, v_social, v_web, p_band, 'pending',
     coalesce(p_personal, false))
  returning * into v;
  return v;
end;
$$;

drop function if exists business_update(uuid, uuid, text, text, text, text, text);
create or replace function business_update(
  p_owner uuid,
  p_business uuid,
  p_name text,
  p_description text,
  p_category text,
  p_social_link text,
  p_website_link text,
  p_personal boolean default null
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

  -- Sending a rejected business again makes it count towards the limit.
  if v.status = 'rejected' then
    perform pg_advisory_xact_lock(hashtext('business_owner:' || p_owner::text));
    if (select count(*) from businesses where owner_id = p_owner and status <> 'rejected') >= 3 then
      raise exception 'business_limit';
    end if;
  end if;

  update businesses set
    name = btrim(p_name),
    description = btrim(p_description),
    category = p_category,
    social_link = v_social,
    website_link = v_web,
    is_personal = coalesce(p_personal, is_personal),
    status = 'pending',
    rejection_reason = null
  where id = p_business
  returning * into v;
  return v;
end;
$$;

revoke execute on function business_register(uuid, text, text, text, text, text, text, boolean) from public;
revoke execute on function business_update(uuid, uuid, text, text, text, text, text, boolean) from public;
grant execute on function business_register(uuid, text, text, text, text, text, text, boolean) to anon, authenticated;
grant execute on function business_update(uuid, uuid, text, text, text, text, text, boolean) to anon, authenticated;

-- ------------------------------------------------- unseen reports (admin) ---
alter table content_reports add column if not exists admin_seen_at timestamptz;
alter table marketplace_reports add column if not exists admin_seen_at timestamptz;

create or replace function admin_reports_unseen_count(p_admin uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return (select count(*)::integer from content_reports where status = 'open' and admin_seen_at is null)
       + (select count(*)::integer from marketplace_reports where status = 'open' and admin_seen_at is null);
end;
$$;

create or replace function admin_reports_mark_seen(p_admin uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  update content_reports set admin_seen_at = now() where status = 'open' and admin_seen_at is null;
  update marketplace_reports set admin_seen_at = now() where status = 'open' and admin_seen_at is null;
end;
$$;

revoke execute on function admin_reports_unseen_count(uuid) from public;
revoke execute on function admin_reports_mark_seen(uuid) from public;
grant execute on function admin_reports_unseen_count(uuid) to anon, authenticated;
grant execute on function admin_reports_mark_seen(uuid) to anon, authenticated;
