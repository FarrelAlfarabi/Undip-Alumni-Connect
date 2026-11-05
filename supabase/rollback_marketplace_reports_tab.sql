-- Undo 20261105150000_marketplace_reports_tab.sql. Safe to run twice.
drop function if exists marketplace_report_details(uuid, text);
drop function if exists marketplace_reports_set_dismissed(uuid, uuid, boolean);
alter table marketplace_reports drop column if exists dismissed_at;
-- marketplace_report_counts keeps working (it only ignored dismissed
-- reports, and with the column gone it must be the old body again):
create or replace function marketplace_report_counts(p_admin uuid, p_key text default null)
returns table (listing_id uuid, report_count bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query
    select r.listing_id, count(*)::bigint
    from marketplace_reports r
    group by r.listing_id
    order by count(*) desc;
end;
$$;
