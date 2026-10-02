-- ============================================================================
-- Marketplace admin passphrase becomes optional (2 Oct 2026, owner decision
-- for the demo). An admin who has NO passphrase set is authorised by profile
-- id alone, as before the SA-04 hardening. An admin who HAS a passphrase
-- still needs it, so the protection comes back by setting one:
--   select marketplace_set_admin_key('<admin profile uuid>', '<16+ chars>');
--
-- SECURITY: while no passphrase is set, anyone who knows the admin's profile
-- id (readable from alumni_profiles with the public key) can approve or reject
-- listings and read the report counts. Acceptable only for demo data. Real
-- fix before real alumni data: real login, with admin decided from the
-- session on the server (SECURITY_AUDIT.md SA-03/SA-04/SA-05).
--
-- Rollback: re-apply the marketplace_admin_authorized function from
-- 20260930100100_security_admin_key.sql, then set a passphrase.
-- ============================================================================

create or replace function marketplace_admin_authorized(p_admin uuid, p_key text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  h text;
begin
  select key_hash into h from marketplace_admins where profile_id = p_admin;
  if found then
    if h is null then return true; end if; -- passphrase switched off
    if p_key is not null and crypt(p_key, h) = h then return true; end if;
  end if;
  perform pg_sleep(1); -- every refusal costs a second
  return false;
end;
$$;
revoke execute on function marketplace_admin_authorized(uuid, text) from public, anon, authenticated;
