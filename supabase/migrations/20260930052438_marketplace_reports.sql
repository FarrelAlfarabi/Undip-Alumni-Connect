-- ============================================================================
-- Marketplace demo: listing reports
--
-- Anyone (anon in this app's auth model) can file a report against an
-- approved listing. Nobody can read reports directly; admins get counts
-- through marketplace_report_counts() in the functions migration.
-- `reporter` is whatever profile id the app sends (unauthenticated).
--
-- Idempotent: safe to re-run.
-- ============================================================================

create table if not exists marketplace_reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references marketplace_listings (id) on delete cascade,
  reporter uuid not null references alumni_profiles (id),
  reason text not null
    check (reason in ('spam', 'prohibited', 'misleading', 'other')),
  note text check (note is null or char_length(note) <= 500),
  created_at timestamptz not null default now(),
  constraint marketplace_reports_one_per_reporter unique (listing_id, reporter)
);

create index if not exists idx_marketplace_reports_listing
  on marketplace_reports (listing_id);

alter table marketplace_reports enable row level security;

drop policy if exists "marketplace_reports_insert" on marketplace_reports;
create policy "marketplace_reports_insert" on marketplace_reports
  for insert to anon, authenticated
  with check (
    exists (
      select 1 from marketplace_listings l
      where l.id = listing_id and l.status = 'approved'
    )
  );

revoke select, update, delete, truncate on marketplace_reports from anon, authenticated;
