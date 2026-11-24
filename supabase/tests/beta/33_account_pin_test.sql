-- One PIN per account (24 Nov 2026): stored as a bcrypt hash, set, checked
-- and removed only by the signed in person, wrong tries counted on the
-- account, a wait from the 3rd wrong try, the 5th wrong try removes the PIN.
\set ON_ERROR_STOP on
\o /dev/null
begin;

create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

update alumni_profiles set verification_status = 'verified', user_id = null, suspended_at = null
  where email in ('ahmad.ramadhan@example.com', 'clara.putri@example.com');

alter table auth.users add column if not exists last_sign_in_at timestamptz;

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon, authenticated;
insert into t_ids select 'ahmad', jt.pid('ahmad.ramadhan@example.com');
insert into t_ids select 'clara', jt.pid('clara.putri@example.com');
insert into t_ids select 'uahmad', gen_random_uuid();
insert into t_ids select 'uclara', gen_random_uuid();
insert into auth.users (id, last_sign_in_at) select v, now() - interval '1 day' from t_ids where k in ('uahmad', 'uclara');
update alumni_profiles set user_id = (select v from t_ids where k = 'uahmad') where id = (select v from t_ids where k = 'ahmad');
update alumni_profiles set user_id = (select v from t_ids where k = 'uclara') where id = (select v from t_ids where k = 'clara');

-- The table is closed to the app roles.
select jt.assert(not has_table_privilege('anon', 'member_pins', 'select'), 'anon cannot read member_pins');
select jt.assert(not has_table_privilege('authenticated', 'member_pins', 'select'), 'authenticated cannot read member_pins');
select jt.assert(not has_function_privilege('anon', 'pin_check(text)', 'execute'), 'anon cannot call pin_check');
select jt.assert(not has_function_privilege('anon', 'pin_set(text, text)', 'execute'), 'anon cannot call pin_set');

-- Not signed in: refused.
select set_config('test.uid', '', false);
set role authenticated;
select jt.expect_error($q$select pin_set('482913')$q$, 'not_signed_in');
select jt.expect_error($q$select pin_check('482913')$q$, 'not_signed_in');
select jt.expect_error($q$select pin_status()$q$, 'not_signed_in');
reset role;

select set_config('test.uid', (select v::text from t_ids where k = 'uahmad'), false);
set role authenticated;
select jt.assert(pin_status() = false, 'no PIN yet');
select jt.assert(pin_check('482913')->>'status' = 'none', 'check without a PIN says none');
select jt.expect_error($q$select pin_set('12345')$q$, 'invalid_pin');
select jt.expect_error($q$select pin_set('12345a')$q$, 'invalid_pin');
select jt.expect_error($q$select pin_set(null)$q$, 'invalid_pin');
select pin_set('482913');
select jt.assert(pin_status() = true, 'PIN set');
-- Replacing it needs the old PIN or a fresh email sign in.
select jt.expect_error($q$select pin_set('111222')$q$, 'old_pin_required');
select jt.expect_error($q$select pin_set('111222', '999999')$q$, 'old_pin_required');
select pin_set('111222', '482913');
select jt.assert(pin_check('111222')->>'status' = 'ok', 'changed with the old PIN');
reset role;
update auth.users set last_sign_in_at = now() where id = (select v from t_ids where k = 'uahmad');
set role authenticated;
select pin_set('482913');
select jt.assert(pin_check('482913')->>'status' = 'ok', 'Lupa PIN: a fresh sign in may set a new one');
reset role;
update auth.users set last_sign_in_at = now() - interval '1 day' where id = (select v from t_ids where k = 'uahmad');

select jt.assert((select pin_hash like '$2a$%' and pin_hash not like '%482913%' from member_pins where profile_id = (select v from t_ids where k = 'ahmad')), 'stored as bcrypt, never plain');

-- Another person cannot see or use Ahmad's PIN.
select set_config('test.uid', (select v::text from t_ids where k = 'uclara'), false);
set role authenticated;
select jt.assert(pin_status() = false, 'Clara has her own (no) PIN');
select jt.assert(pin_check('482913')->>'status' = 'none', 'Ahmad''s PIN does not open Clara');
reset role;

select set_config('test.uid', (select v::text from t_ids where k = 'uahmad'), false);
set role authenticated;
select jt.assert(pin_check('482913')->>'status' = 'ok', 'right PIN');
select jt.assert((pin_check('000001')->>'left')::int = 4, 'wrong 1, 4 left');
select jt.assert((pin_check('000002')->>'left')::int = 3, 'wrong 2, 3 left');
select jt.assert((pin_check('000003') ->> 'wait_until') is not null, 'wrong 3 starts a wait');
select jt.assert(pin_check('482913')->>'status' = 'wait', 'even the right PIN waits');
reset role;
update member_pins set wait_until = now() - interval '1 second' where profile_id = (select v from t_ids where k = 'ahmad');
set role authenticated;
select jt.assert(pin_check('482913')->>'status' = 'ok', 'right PIN after the wait resets the count');
reset role;
select jt.assert((select failed = 0 and wait_until is null from member_pins where profile_id = (select v from t_ids where k = 'ahmad')), 'count reset');

-- A wrong try older than an hour no longer counts.
update member_pins set failed = 4, last_wrong_at = now() - interval '2 hours' where profile_id = (select v from t_ids where k = 'ahmad');
set role authenticated;
select jt.assert((pin_check('000009')->>'left')::int = 4, 'old wrong tries expired');
reset role;
update member_pins set failed = 0, wait_until = null, last_wrong_at = null where profile_id = (select v from t_ids where k = 'ahmad');

-- Five wrong in a row removes the PIN.
do $$
declare r jsonb;
begin
  for i in 1..5 loop
    update member_pins set wait_until = null where profile_id = jt.pid('ahmad.ramadhan@example.com');
    set local role authenticated;
    r := pin_check('00000' || i);
    reset role;
  end loop;
  if r->>'status' <> 'locked' then raise exception 'expected locked, got %', r; end if;
end $$;
select jt.assert(not exists (select 1 from member_pins where profile_id = (select v from t_ids where k = 'ahmad')), '5th wrong removes the PIN');

-- Locked out: no row, so a new PIN needs no old one.
set role authenticated;
select pin_set('482913');
select pin_remove();
select jt.assert(pin_status() = false, 'removed');
reset role;

-- The row goes with the profile.
select jt.assert((select confdeltype = 'c' from pg_constraint where conrelid = 'member_pins'::regclass and contype = 'f'), 'on delete cascade');

-- A suspended member is signed out for PIN purposes too.
update alumni_profiles set suspended_at = now() where id = (select v from t_ids where k = 'ahmad');
set role authenticated;
select jt.expect_error($q$select pin_set('482913')$q$, 'not_signed_in');
reset role;

\o
select 'ok 33_account_pin';
rollback;
