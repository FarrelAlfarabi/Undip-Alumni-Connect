-- Undo 20261003090000_remove_subscription_gate.sql. Safe to run twice.
-- Puts back the subscriber rule on job_posts, the subscriber check in
-- marketplace_create_listing, and demo_subscribe. No data is touched.
drop trigger if exists job_posts_require_verified_poster_trigger on job_posts;
drop function if exists job_posts_require_verified_poster();

create or replace function job_posts_require_subscriber()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if new.posted_by is null or not exists (
    select 1 from alumni_profiles
    where id = new.posted_by and subscription_status = 'subscribed'
  ) then
    raise exception 'subscriber_required';
  end if;
  return new;
end;
$$;
revoke execute on function job_posts_require_subscriber() from public, anon, authenticated;

drop trigger if exists job_posts_require_subscriber_trigger on job_posts;
create trigger job_posts_require_subscriber_trigger
  before insert on job_posts
  for each row execute function job_posts_require_subscriber();

create or replace function marketplace_create_listing(
  p_seller uuid,
  p_title text,
  p_description text,
  p_price_idr integer,
  p_category text,
  p_city text,
  p_image_url text,
  p_shop_url text,
  p_contact_info text
)
returns marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v marketplace_listings;
begin
  if not exists (
    select 1 from alumni_profiles
    where id = p_seller and subscription_status = 'subscribed'
  ) then
    raise exception 'subscriber_required';
  end if;

  insert into marketplace_listings
    (seller_id, title, description, price_idr, category, city, image_url,
     shop_url, contact_info, status)
  values
    (p_seller, btrim(p_title), btrim(p_description), p_price_idr, p_category,
     btrim(p_city), p_image_url, nullif(btrim(p_shop_url), ''),
     nullif(btrim(p_contact_info), ''), 'pending')
  returning * into v;

  return v;
end;
$$;
revoke execute on function marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text) from public;
grant execute on function marketplace_create_listing(uuid, text, text, integer, text, text, text, text, text) to anon, authenticated;

update billing_settings set demo_subscriptions = true;
do $$
begin
  if to_regprocedure('demo_subscribe(uuid)') is not null then
    grant execute on function demo_subscribe(uuid) to anon, authenticated;
  end if;
end $$;
