-- Marketplace review > Reports tab, completed. An admin sees, per reported
-- product: who sold it, who reported it and why, the notes, and whether it is
-- hidden. They can dismiss the reports (kept, not deleted, so it can be
-- undone) or hide the product (admin_reports_decide 'product' hide/restore).
alter table marketplace_reports add column if not exists dismissed_at timestamptz;

-- The count only includes reports nobody has dismissed.
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
    where r.dismissed_at is null
    group by r.listing_id
    order by count(*) desc;
end;
$$;

-- One row per reported product. p_view 'open' = has undismissed reports,
-- 'dismissed' = every report was dismissed.
create or replace function marketplace_report_details(p_admin uuid, p_view text default 'open')
returns table (
  listing_id uuid,
  title text,
  seller_id uuid,
  seller_name text,
  report_count bigint,
  reporters text[],
  reasons text[],
  notes text[],
  last_reported timestamptz,
  hidden_at timestamptz,
  hidden_reason text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  if p_view is null or p_view not in ('open', 'dismissed') then
    raise exception 'invalid_view';
  end if;
  return query
    select l.id, l.title, l.seller_id, s.name,
           count(*)::bigint,
           array_agg(coalesce(rp.name, 'Alumni') order by r.created_at),
           array_agg(r.reason order by r.created_at),
           array_agg(coalesce(r.note, '') order by r.created_at),
           max(r.created_at),
           l.hidden_at, l.hidden_reason
      from marketplace_reports r
      join marketplace_listings l on l.id = r.listing_id
      left join alumni_profiles s on s.id = l.seller_id
      left join alumni_profiles rp on rp.id = r.reporter
     where (p_view = 'open' and r.dismissed_at is null)
        or (p_view = 'dismissed' and r.dismissed_at is not null
            and not exists (select 1 from marketplace_reports r2
                             where r2.listing_id = r.listing_id and r2.dismissed_at is null))
     group by l.id, l.title, l.seller_id, s.name, l.hidden_at, l.hidden_reason
     order by max(r.created_at) desc;
end;
$$;

-- Dismiss (true) or reopen (false) every report on one product.
create or replace function marketplace_reports_set_dismissed(
  p_admin uuid, p_listing uuid, p_dismissed boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  perform app_admin_assert(p_admin);
  update marketplace_reports
     set dismissed_at = case when p_dismissed then now() end
   where listing_id = p_listing;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'not_found'; end if;
end;
$$;

revoke execute on function marketplace_report_details(uuid, text) from public;
revoke execute on function marketplace_reports_set_dismissed(uuid, uuid, boolean) from public;
grant execute on function marketplace_report_details(uuid, text) to anon, authenticated;
grant execute on function marketplace_reports_set_dismissed(uuid, uuid, boolean) to anon, authenticated;
