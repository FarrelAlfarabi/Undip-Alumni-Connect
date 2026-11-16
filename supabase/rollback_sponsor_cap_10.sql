-- Rollback of 20261116100000_sponsor_cap_10: back to no limit.
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
