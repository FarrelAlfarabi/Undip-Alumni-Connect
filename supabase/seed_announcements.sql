-- ============================================================================
-- Seed data — announcements (Day 7 demo)
--
-- One-way broadcast from ILUNI admin, matching the pitch deck's News
-- mockup content. posted_by is left null — there's no "ILUNI admin" user
-- account in this demo, the app just labels the source "ILUNI UNDIP" in
-- the UI (announcements_screen.dart).
--
-- Not idempotent-guarded — re-running duplicates. Safe to run once.
-- ============================================================================

insert into announcements (title, body)
values
  (
    'Reuni Akbar 2026',
    'Pendaftaran Reuni Akbar 2026 dibuka minggu ini. Daftarkan dirimu segera melalui link yang akan dibagikan ke seluruh anggota ILUNI.'
  ),
  (
    'Beasiswa Mentoring untuk Lulusan Baru',
    'ILUNI UNDIP membuka program beasiswa mentoring untuk lulusan baru. Cek detail dan persyaratan pendaftaran di kantor sekretariat ILUNI.'
  ),
  (
    'Jadwal Temu Alumni per Fakultas',
    'Jadwal temu alumni per fakultas untuk bulan November 2026 telah dirilis. Silakan hubungi pengurus fakultas masing-masing untuk informasi lebih lanjut.'
  );
