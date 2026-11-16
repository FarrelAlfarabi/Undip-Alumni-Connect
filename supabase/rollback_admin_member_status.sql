-- Rollback of 20261116131000_admin_member_status: drops the member list,
-- status and jurusan fix functions. Suspensions and fixes already made stay.
-- Roll the app back first: app builds from this change call admin_members_list.
drop function if exists admin_members_list(uuid, text);
drop function if exists admin_member_set_suspended(uuid, uuid, boolean, text);
drop function if exists admin_member_set_major(uuid, uuid, text);
