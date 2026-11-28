-- Undo 20261128100000_sponsor_logo_temp_allow.sql: strict rule back (sponsor
-- pictures only from the sponsor-images bucket). Run only after every sponsor
-- uses a bucket picture, otherwise adding the constraint fails. First put the
-- originals back for any row still on a vercel.app address (the original
-- addresses were read from the PROD rows on 2026-11-28):
update sponsors set image_url = 'https://hotbjigrocdofykrlsef.supabase.co/storage/v1/object/public/sponsor-images/jamkrindo.jpg' where id = 'd0d0d0d0-0000-4000-8000-000000000500' and image_url like 'https://lingkaran-ikafe.vercel.app/%';
update sponsors set image_url = 'https://hotbjigrocdofykrlsef.supabase.co/storage/v1/object/public/sponsor-images/jamkrindo-syariah.jpg' where id = 'd0d0d0d0-0000-4000-8000-000000000501' and image_url like 'https://lingkaran-ikafe.vercel.app/%';
update sponsors set image_url = 'https://hotbjigrocdofykrlsef.supabase.co/storage/v1/object/public/sponsor-images/nindya-karya.jpg' where id = 'd0d0d0d0-0000-4000-8000-000000000503' and image_url like 'https://lingkaran-ikafe.vercel.app/%';
update sponsors set image_url = 'https://hotbjigrocdofykrlsef.supabase.co/storage/v1/object/public/sponsor-images/dw-makeup.jpg' where id = 'd0d0d0d0-0000-4000-8000-000000000505' and image_url like 'https://lingkaran-ikafe.vercel.app/%';
update sponsors set image_url = 'https://hotbjigrocdofykrlsef.supabase.co/storage/v1/object/public/sponsor-images/streetcaxx.jpg' where id = 'd0d0d0d0-0000-4000-8000-000000000506' and image_url like 'https://lingkaran-ikafe.vercel.app/%';

alter table sponsors drop constraint if exists sponsors_image_url_check;
alter table sponsors add constraint sponsors_image_url_check
  check (image_url ~ '^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/public/sponsor-images/[^?#]+$');

-- admin_sponsor_save back to the strict rule (copy of 20261110130000_sponsors.sql).
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
