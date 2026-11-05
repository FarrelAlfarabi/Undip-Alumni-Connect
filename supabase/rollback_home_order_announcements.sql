-- Undo 20261105160000_home_order_announcements.sql. Safe to run twice.
-- The two functions go back to products and jobs only: run again the
-- function parts of 20261030150000_home_order.sql after this file.
drop trigger if exists announcements_home_rank_guard on announcements;
alter table announcements drop constraint if exists announcements_home_rank_check;
alter table announcements drop column if exists home_rank;
