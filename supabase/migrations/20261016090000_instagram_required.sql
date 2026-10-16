-- ============================================================================
-- Instagram is required, the website is optional (16 Oct 2026).
--
-- business_register / business_update now refuse a business without an
-- Instagram link ('link_required'). The app turns @username into
-- https://instagram.com/username before sending. Same signatures as before.
-- Businesses saved earlier with only a website stay as they are; the table
-- check businesses_has_link (social or website) is left alone on purpose, so
-- no existing row is touched. They must add Instagram on their next edit.
-- Idempotent. Rollback: supabase/rollback_instagram_required.sql
-- ============================================================================

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
  if v_social is null then raise exception 'link_required'; end if;
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
  if v_social is null then raise exception 'link_required'; end if;
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
