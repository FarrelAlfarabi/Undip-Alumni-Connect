-- Rollback of 20261116140000_admin_manage_admins. Admin rows added in the
-- app stay (remove them in the dashboard if needed); Riwayat rows stay.
drop function if exists admin_admins_list(uuid);
drop function if exists admin_admin_add(uuid, uuid);
drop function if exists admin_admin_remove(uuid, uuid);
alter table app_admins drop column if exists is_owner;
