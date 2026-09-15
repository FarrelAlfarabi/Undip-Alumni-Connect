-- ============================================================================
-- Seed data — announcements (Day 7 demo)
--
-- One-way broadcast from Ikafe admin, matching the pitch deck's News
-- mockup content. posted_by is left null — there's no "Ikafe admin" user
-- account in this demo, the app just labels the source "Ikafe" in
-- the UI (announcements_screen.dart).
--
-- Not idempotent-guarded — re-running duplicates. Safe to run once.
-- ============================================================================

insert into announcements (title, body)
values
  (
    'Reuni Akbar 2026',
    'Pendaftaran Reuni Akbar 2026 dibuka minggu ini. Daftarkan dirimu segera melalui link yang akan dibagikan ke seluruh anggota Ikafe.'
  ),
  (
    'Beasiswa Mentoring untuk Lulusan Baru',
    'Ikafe membuka program beasiswa mentoring untuk lulusan baru. Cek detail dan persyaratan pendaftaran di kantor sekretariat Ikafe.'
  ),
  (
    'Jadwal Temu Alumni per Fakultas',
    'Jadwal temu alumni per fakultas untuk bulan November 2026 telah dirilis. Silakan hubungi pengurus fakultas masing-masing untuk informasi lebih lanjut.'
  );
