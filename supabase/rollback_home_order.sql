-- Undo 20261030150000_home_order.sql. Safe to run twice.
-- Drops the functions, the guard triggers and both home_rank columns.
-- Home goes back to showing the newest items only.
drop function if exists admin_home_order_list(uuid, text);
drop function if exists admin_set_home_order(uuid, text, uuid[]);
drop trigger if exists marketplace_listings_home_rank_guard on marketplace_listings;
drop trigger if exists job_posts_home_rank_guard on job_posts;
drop function if exists home_rank_members_cannot_write();
alter table marketplace_listings drop column if exists home_rank;
alter table job_posts drop column if exists home_rank;
