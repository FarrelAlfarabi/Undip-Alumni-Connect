-- Categories table: readable, not writable by the app; new names usable by
-- business_register/business_update; unknown names refused; a category hidden
-- later still lets an old row be saved but cannot be chosen again.
\set ON_ERROR_STOP on
\o /dev/null
begin;

update alumni_profiles set verification_status = 'verified'
  where email in ('ahmad.ramadhan@example.com', 'siti.azizah@example.com');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to anon;

select jt.assert((select count(*) from categories where active) >= 17, 'seeded: five old names and the new ones');
select jt.assert((select count(*) from categories where name in ('Food & Drink', 'Fashion', 'Electronics', 'Services', 'Other')) = 5, 'old names still valid');
select jt.assert(exists (select 1 from pg_trigger where tgname = 'trg_marketplace_category'), 'marketplace trigger exists');
select jt.assert(exists (select 1 from pg_trigger where tgname = 'trg_business_category'), 'business trigger exists');

set role anon;
select jt.assert((select count(*) from categories) >= 17, 'anon can read');
select jt.expect_error($q$insert into categories (name) values ('Hacked')$q$, 'permission denied');
select jt.expect_error($q$update categories set active = false$q$, 'permission denied');
select jt.expect_error($q$delete from categories$q$, 'permission denied');

-- A new category works.
insert into t_ids select 'b1', id from business_register(jt.pid('ahmad.ramadhan@example.com'), 'Salon Ahmad', 'Potong rambut', 'Beauty & Health', 'https://instagram.com/salon_ahmad', null, 'micro');
select jt.assert((select category from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')) = 'Beauty & Health', 'new category saved');

-- An unknown name is refused on register and on update.
select jt.expect_error(format($q$select business_register(%L, 'Zzz Usaha', 'd', 'Nonsense', 'https://instagram.com/zzz_usaha', null, 'micro')$q$, jt.pid('siti.azizah@example.com')), 'invalid_category');
select jt.expect_error(format($q$select business_update(%L, %L, 'Salon Ahmad', 'd', 'Nonsense', 'https://instagram.com/salon_ahmad', null)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'invalid_category');

-- The dashboard hides a category: the old row can still be saved with it,
-- but nobody can pick it for a new row or switch to it.
reset role;
update categories set active = false where name = 'Beauty & Health';
set role anon;
select business_update(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), 'Salon Ahmad Baru', 'd', 'Beauty & Health', 'https://instagram.com/salon_ahmad', null);
select jt.assert((select name from business_my(jt.pid('ahmad.ramadhan@example.com')) where id = (select v from t_ids where k = 'b1')) = 'Salon Ahmad Baru', 'old row saves with a hidden category');
select jt.expect_error(format($q$select business_register(%L, 'Salon Dua', 'd', 'Beauty & Health', 'https://instagram.com/salon_dua', null, 'micro')$q$, jt.pid('siti.azizah@example.com')), 'invalid_category');
select business_update(jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1'), 'Salon Ahmad Baru', 'd', 'Other', 'https://instagram.com/salon_ahmad', null);
select jt.expect_error(format($q$select business_update(%L, %L, 'Salon Ahmad Baru', 'd', 'Beauty & Health', 'https://instagram.com/salon_ahmad', null)$q$, jt.pid('ahmad.ramadhan@example.com'), (select v from t_ids where k = 'b1')), 'invalid_category');

-- The dashboard role may still set any value; renames cascade; used names cannot be deleted.
reset role;
select jt.expect_error($q$update businesses set category = 'Nonsense'$q$, 'violates foreign key');
select jt.expect_error($q$delete from categories where name = 'Other'$q$, 'violates foreign key|violates RESTRICT|still referenced');
select jt.expect_error($q$insert into categories (name) values (' Padded ')$q$, 'categories_name_check');
select jt.expect_error($q$insert into categories (name) values ('beauty & health')$q$, 'categories_name_lower_idx');
update businesses set category = 'Beauty & Health' where name = 'Salon Ahmad Baru';
update categories set name = 'Salon dan Kecantikan' where name = 'Beauty & Health';
select jt.assert((select category from businesses where name = 'Salon Ahmad Baru') = 'Salon dan Kecantikan', 'rename cascades to items');

rollback;
\o
select 'categories ok';
