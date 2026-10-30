-- ============================================================================
-- Kontak Ikafe: the official Ikafe contacts and socials shown on Home.
-- Replaces Nearby Alumni (the city WhatsApp group table from
-- 20261019110000 is left alone, nothing reads it any more).
--
-- ikafe_contacts: everyone can read the ACTIVE rows (public information, so
-- there is nothing to hide). NO insert/update/delete policy exists, so the app
-- roles cannot write the table. Admins write through three SECURITY DEFINER
-- functions that check app_admins (app_admin_assert). Farrel can also edit the
-- table in the Supabase dashboard at any time.
--
-- kind is whatsapp, email, instagram, linkedin or website. label is 1 to 60
-- characters and value 1 to 200, after trimming (invalid_input).
-- The five rows seeded below are EXAMPLES (example.com style values). Replace
-- them with Ikafe's real contacts in Admin > Kontak Ikafe.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_ikafe_contacts.sql
-- ============================================================================

create table if not exists ikafe_contacts (
  id uuid primary key default gen_random_uuid(),
  kind text not null
    check (kind in ('whatsapp', 'email', 'instagram', 'linkedin', 'website')),
  label text not null check (char_length(label) between 1 and 60),
  value text not null check (char_length(value) between 1 and 200),
  sort_order integer not null default 0,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table ikafe_contacts enable row level security;
revoke all on ikafe_contacts from public, anon, authenticated;
grant select on ikafe_contacts to anon, authenticated;

drop policy if exists ikafe_contacts_read_active on ikafe_contacts;
create policy ikafe_contacts_read_active on ikafe_contacts
  for select to anon, authenticated using (active);

create or replace function admin_ikafe_contact_list(p_admin uuid)
returns table (
  id uuid,
  kind text,
  label text,
  value text,
  sort_order integer,
  active boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select c.id, c.kind, c.label, c.value, c.sort_order, c.active
    from ikafe_contacts c
    order by c.sort_order, c.label, c.id;
end;
$$;

-- p_id null adds a row, otherwise changes that row (not_found if it is gone).
create or replace function admin_ikafe_contact_save(
  p_admin uuid,
  p_id uuid,
  p_kind text,
  p_label text,
  p_value text,
  p_sort integer,
  p_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_label text := btrim(coalesce(p_label, ''), E' \t\r\n');
  v_value text := btrim(coalesce(p_value, ''), E' \t\r\n');
  v_id uuid;
begin
  perform app_admin_assert(p_admin);
  if p_kind is null
     or p_kind not in ('whatsapp', 'email', 'instagram', 'linkedin', 'website')
     or v_label = '' or v_value = ''
     or char_length(v_label) > 60 or char_length(v_value) > 200 then
    raise exception 'invalid_input';
  end if;
  if p_id is null then
    insert into ikafe_contacts (kind, label, value, sort_order, active)
      values (p_kind, v_label, v_value, coalesce(p_sort, 0), coalesce(p_active, true))
      returning ikafe_contacts.id into v_id;
    return v_id;
  end if;
  update ikafe_contacts
     set kind = p_kind, label = v_label, value = v_value,
         sort_order = coalesce(p_sort, 0), active = coalesce(p_active, true),
         updated_at = now()
   where ikafe_contacts.id = p_id
   returning ikafe_contacts.id into v_id;
  if v_id is null then raise exception 'not_found'; end if;
  return v_id;
end;
$$;

create or replace function admin_ikafe_contact_delete(p_admin uuid, p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  delete from ikafe_contacts where id = p_id;
  if not found then raise exception 'not_found'; end if;
end;
$$;

revoke execute on function admin_ikafe_contact_list(uuid) from public;
revoke execute on function admin_ikafe_contact_save(uuid, uuid, text, text, text, integer, boolean) from public;
revoke execute on function admin_ikafe_contact_delete(uuid, uuid) from public;
grant execute on function admin_ikafe_contact_list(uuid) to anon, authenticated;
grant execute on function admin_ikafe_contact_save(uuid, uuid, text, text, text, integer, boolean) to anon, authenticated;
grant execute on function admin_ikafe_contact_delete(uuid, uuid) to anon, authenticated;

-- Example rows, only when the table is empty (so re-running changes nothing).
insert into ikafe_contacts (kind, label, value, sort_order)
select * from (values
  ('whatsapp', 'WhatsApp Ikafe', '+6200000000000', 1),
  ('email', 'Email Ikafe', 'kontak@ikafe.example', 2),
  ('instagram', 'Instagram Ikafe', '@ikafe_contoh', 3),
  ('linkedin', 'LinkedIn Ikafe', 'linkedin.com/company/ikafe-contoh', 4),
  ('website', 'Website Ikafe', 'ikafe.example', 5)
) v (kind, label, value, sort_order)
where not exists (select 1 from ikafe_contacts);
