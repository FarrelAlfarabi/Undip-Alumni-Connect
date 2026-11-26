-- Kontak Ikafe: add the "youtube" kind (26 Nov 2026).
-- Widens the kind check on ikafe_contacts and the kind lists inside
-- admin_ikafe_contact_save and admin_ikafe_contact_restore. Idempotent.
-- Rollback: supabase/rollback_ikafe_youtube_kind.sql

alter table ikafe_contacts drop constraint if exists ikafe_contacts_kind_check;
alter table ikafe_contacts add constraint ikafe_contacts_kind_check
  check (kind in ('whatsapp', 'email', 'instagram', 'linkedin', 'website', 'youtube'));

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
     or p_kind not in ('whatsapp', 'email', 'instagram', 'linkedin', 'website', 'youtube')
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

create or replace function admin_ikafe_contact_restore(
  p_admin uuid,
  p_id uuid,
  p_kind text,
  p_label text,
  p_value text,
  p_sort integer,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  if p_kind is null
     or p_kind not in ('whatsapp', 'email', 'instagram', 'linkedin', 'website', 'youtube')
     or btrim(coalesce(p_label, '')) = '' or btrim(coalesce(p_value, '')) = ''
     or char_length(p_label) > 60 or char_length(p_value) > 200 then
    raise exception 'invalid_input';
  end if;
  insert into ikafe_contacts (id, kind, label, value, sort_order, active)
    values (p_id, p_kind, btrim(p_label), btrim(p_value), coalesce(p_sort, 0), coalesce(p_active, true))
    on conflict (id) do nothing;
end;
$$;

revoke execute on function admin_ikafe_contact_save(uuid, uuid, text, text, text, integer, boolean) from public;
revoke execute on function admin_ikafe_contact_restore(uuid, uuid, text, text, text, integer, boolean) from public;
grant execute on function admin_ikafe_contact_save(uuid, uuid, text, text, text, integer, boolean) to anon, authenticated;
grant execute on function admin_ikafe_contact_restore(uuid, uuid, text, text, text, integer, boolean) to anon, authenticated;
