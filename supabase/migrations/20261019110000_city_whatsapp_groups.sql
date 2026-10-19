-- ============================================================================
-- City WhatsApp groups: one invite link per city, any verified member can set it.
--
-- WhatsApp has no way to create a group from an app, so the app keeps one
-- invite link per city and the Nearby list opens it with "Join WhatsApp group".
-- A member creates the group in WhatsApp and pastes the invite link in the app.
--
-- The table is closed (RLS on, no policy, no grants). The app only goes through
-- the two functions below, which check that the caller is a verified member.
-- The link must look like https://chat.whatsapp.com/<code>, so the app cannot be
-- used to hand out other kinds of links. City is 1 to 80 characters.
-- The dashboard (postgres / service_role) can still view and edit every row.
--
-- HONEST LIMIT: the app has no real login yet, so the profile id passed in is not
-- authenticated (same limit as contact requests). Anyone who knows a verified
-- profile id could replace a city's link with another WhatsApp group link.
-- set_by records who last changed it so the dashboard can undo it.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_city_whatsapp_groups.sql
-- ============================================================================

create table if not exists city_whatsapp_groups (
  city text primary key check (char_length(city) between 1 and 80),
  invite_url text not null
    check (invite_url ~ '^https://chat\.whatsapp\.com/[A-Za-z0-9]{10,40}$'),
  set_by uuid references alumni_profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);

-- "semarang" and "Semarang" are the same city.
create unique index if not exists city_whatsapp_groups_city_lower
  on city_whatsapp_groups (lower(city));

alter table city_whatsapp_groups enable row level security;
revoke all on city_whatsapp_groups from public, anon, authenticated;

create or replace function city_whatsapp_groups_list(p_viewer uuid)
returns table (city text, invite_url text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not business_is_verified(p_viewer) then raise exception 'not_verified'; end if;
  return query
    select g.city, g.invite_url from city_whatsapp_groups g order by g.city;
end;
$$;

create or replace function city_whatsapp_group_set(
  p_profile uuid,
  p_city text,
  p_url text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_city text := btrim(coalesce(p_city, ''), E' \t\r\n');
  v_url text := btrim(coalesce(p_url, ''), E' \t\r\n');
begin
  if not business_is_verified(p_profile) then raise exception 'not_verified'; end if;
  if v_city = '' or char_length(v_city) > 80 or v_city ~ '[[:cntrl:]]'
     or v_url !~ '^https://chat\.whatsapp\.com/[A-Za-z0-9]{10,40}$' then
    raise exception 'invalid_input';
  end if;
  update city_whatsapp_groups
    set invite_url = v_url, set_by = p_profile, updated_at = now()
    where lower(city) = lower(v_city);
  if not found then
    insert into city_whatsapp_groups (city, invite_url, set_by, updated_at)
      values (v_city, v_url, p_profile, now());
  end if;
end;
$$;

revoke execute on function city_whatsapp_groups_list(uuid) from public;
revoke execute on function city_whatsapp_group_set(uuid, text, text) from public;
grant execute on function city_whatsapp_groups_list(uuid) to anon, authenticated;
grant execute on function city_whatsapp_group_set(uuid, text, text) to anon, authenticated;
