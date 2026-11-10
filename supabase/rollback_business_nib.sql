-- Undo 20261110140000_business_nib.sql. Safe to run twice.
-- The NIB numbers and ticks typed so far are deleted with the columns.
-- Copy them out first if they matter:
--   select id, name, nib, nib_verified from businesses where nib is not null;
drop function if exists admin_business_nib_verify(uuid, uuid, boolean);
drop function if exists admin_business_nibs(uuid);
drop function if exists business_nib_verified_ids(uuid);
drop function if exists business_set_nib(uuid, uuid, text);
drop trigger if exists trg_businesses_nib_reset on businesses;
drop function if exists businesses_nib_reset();
alter table businesses drop constraint if exists businesses_nib_verified_needs_nib;
alter table businesses drop constraint if exists businesses_nib_format;
alter table businesses drop column if exists nib_verified_by;
alter table businesses drop column if exists nib_verified_at;
alter table businesses drop column if exists nib_verified;
alter table businesses drop column if exists nib;
