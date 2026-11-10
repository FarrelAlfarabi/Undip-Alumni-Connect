-- Optional NIB: 13 digits, set by the owner, the tick set only by an admin,
-- the tick lost when the number changes, never shown to other alumni.
-- All app calls run as anon.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com', 'clara.putri@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;
insert into app_admins (profile_id, note) values (jt.pid('clara.putri@example.com'), 'test');

set role anon;

insert into t_ids select 'b1', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Nib Satu', 'd', 'Other', 'https://instagram.com/nib_one', null, 'micro');
select jt.assert((select nib is null and not nib_verified from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')), 'no NIB by default');

-- Format: exactly 13 digits (spaces and dashes are cleaned).
select jt.expect_error(format($q$select business_set_nib(%L, %L, '12345')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'invalid_nib');
select jt.expect_error(format($q$select business_set_nib(%L, %L, '12345678901234')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'invalid_nib');
select jt.expect_error(format($q$select business_set_nib(%L, %L, '12345678901ab')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'invalid_nib');

-- Only the owner.
select jt.expect_error(format($q$select business_set_nib(%L, %L, '1234567890123')$q$, jt.pid('siti.azizah@example.com'), (select v from t_ids where k = 'b1')), 'not_owner');
select jt.expect_error(format($q$select business_set_nib(%L, gen_random_uuid(), '1234567890123')$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_found');

-- Owner sets it. Spaces and dashes are removed. It is NOT verified.
select business_set_nib(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), '1234 5678-90123');
select jt.assert((select nib = '1234567890123' and not nib_verified from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')), 'owner sets NIB, still not verified');

-- The owner cannot verify: no direct table access, no admin function.
select jt.expect_error(format($q$update businesses set nib_verified = true where id = %L$q$, (select v from t_ids where k = 'b1')), 'permission denied');
select jt.expect_error(format($q$select admin_business_nib_verify(%L, %L, true)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'not_admin');
select jt.expect_error(format($q$select admin_business_nibs(%L)$q$, jt.pid('ahmad.ramadhan@example.com')), 'not_admin');
select jt.expect_error(format($q$select admin_business_nibs(%L)$q$, jt.pid('siti.azizah@example.com')), 'not_admin');

-- register / update never touch the flag or the number.
select business_update(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), 'Nib Satu B', 'd', 'Other', 'https://instagram.com/nib_one', null);
select jt.assert((select nib = '1234567890123' and not nib_verified from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')), 'business_update leaves NIB alone');

-- Admin sees the NIB and verifies it.
select jt.assert((select nib = '1234567890123' and not nib_verified from admin_business_nibs(jt.pid('clara.putri@example.com')) where business_id = (select v from t_ids where k = 'b1')), 'admin sees NIB');
select jt.expect_error(format($q$select admin_business_nib_verify(%L, gen_random_uuid(), true)$q$, jt.pid('clara.putri@example.com')), 'not_found');
select admin_business_nib_verify(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b1'), true);
select jt.assert((select nib_verified and nib_verified_at is not null and nib_verified_by = jt.pid('clara.putri@example.com') from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')), 'admin verified, with who and when');

-- A pending business does not show the tick to others yet.
select jt.assert((select count(*) from business_nib_verified_ids(jt.pid('siti.azizah@example.com'))) = 0, 'no tick while pending');
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b1'), 'approve', 'micro', null);
select jt.assert((select count(*) from business_nib_verified_ids(jt.pid('siti.azizah@example.com')) where business_id = (select v from t_ids where k = 'b1')) = 1, 'tick shows once approved');

-- Hidden business: no tick. Unverified viewer: refused.
select jt.expect_error(format($q$select business_nib_verified_ids(%L)$q$, gen_random_uuid()), 'not_verified');
reset role;
update businesses set hidden_at = now() where id = (select v from t_ids where k = 'b1');
set role anon;
select jt.assert((select count(*) from business_nib_verified_ids(jt.pid('siti.azizah@example.com'))) = 0, 'hidden business shows no tick');
reset role;
update businesses set hidden_at = null where id = (select v from t_ids where k = 'b1');
set role anon;

-- Other alumni never get the number from the directory.
select jt.assert((select count(*) from business_directory(jt.pid('siti.azizah@example.com')) d where to_jsonb(d) ? 'nib') = 0, 'directory rows carry no nib');
select jt.assert((select count(*) from business_directory(jt.pid('siti.azizah@example.com'))) >= 1, 'directory still lists the business');
select jt.expect_error(format($q$select * from businesses where id = %L$q$, (select v from t_ids where k = 'b1')), 'permission denied');

-- Approved business: owner can still change the NIB, and the change takes the tick away.
select business_set_nib(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), '9999999999999');
select jt.assert((select nib = '9999999999999' and not nib_verified and nib_verified_at is null and nib_verified_by is null from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')), 'changed NIB loses the tick');
select jt.assert((select count(*) from business_nib_verified_ids(jt.pid('siti.azizah@example.com'))) = 0, 'tick gone for others');

-- Same number saved again keeps a tick.
select admin_business_nib_verify(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b1'), true);
select business_set_nib(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), '9999999999999');
select jt.assert((select nib_verified from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')), 'same number keeps the tick');

-- A rejected business can set a NIB too.
insert into t_ids select 'b2', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Nib Dua', 'd', 'Other', 'https://instagram.com/nib_two', null, 'micro');
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b2'), 'reject', null, 'blur');
select business_set_nib(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b2'), '3333333333333');
select jt.assert((select nib = '3333333333333' from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b2')), 'rejected business can set NIB');

-- Clearing the number clears the tick (and the table check holds).
select business_set_nib(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), '  ');
select jt.assert((select nib is null and not nib_verified from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')), 'cleared NIB clears the tick');

-- Cannot verify a business that has no NIB. Admin can take a tick away.
select jt.expect_error(format($q$select admin_business_nib_verify(%L, %L, true)$q$, jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b1')), 'nib_required');
select business_set_nib(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), '1111111111111');
select admin_business_nib_verify(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b1'), true);
select admin_business_nib_verify(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b1'), false);
select jt.assert((select not nib_verified and nib_verified_by is null from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')), 'admin can revoke');

-- A suspended business shows no tick and cannot change its NIB.
select admin_business_nib_verify(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b1'), true);
select admin_business_decide(jt.pid('clara.putri@example.com'), (select v from t_ids where k = 'b1'), 'suspend', null, 'test');
select jt.assert((select count(*) from business_nib_verified_ids(jt.pid('siti.azizah@example.com'))) = 0, 'suspended business shows no tick');
select jt.expect_error(format($q$select business_set_nib(%L, %L, '2222222222222')$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'locked');

-- The table check refuses a bad number even from the dashboard role.
reset role;
select jt.expect_error(format($q$update businesses set nib = 'abc' where id = %L$q$, (select v from t_ids where k = 'b1')), 'businesses_nib_format');
update businesses set nib = null where id = (select v from t_ids where k = 'b1');
select jt.assert((select not nib_verified from businesses where id = (select v from t_ids where k = 'b1')), 'dashboard: clearing the number clears the tick');
select jt.expect_error(format($q$update businesses set nib_verified = true where id = %L$q$, (select v from t_ids where k = 'b1')), 'businesses_nib_verified_needs_nib');

rollback;
\o
\echo business NIB checks passed
