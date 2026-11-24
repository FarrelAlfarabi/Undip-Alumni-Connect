-- Rollback for 20261124100000_account_pin.sql. Removes the account PIN
-- functions and table. Devices keep their own cached PIN, so the app falls
-- back to one PIN per device (as before 24 Nov 2026). Idempotent.
drop function if exists pin_remove();
drop function if exists pin_check(text);
drop function if exists pin_set(text, text);
drop function if exists pin_set(text);
drop function if exists pin_status();
drop function if exists pin_caller();
drop table if exists member_pins;
