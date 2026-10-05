-- ============================================================================
-- Seed data: marketplace demo (12 dummy listings)
--
-- DEMO ONLY: dummy data, no real payments. All contact info is obviously
-- fake (0800-0000-xxxx numbers, example.com emails and shop links). Images
-- are deterministic placeholders from picsum.photos (needs internet when
-- the app is viewed).
--
-- Depends on seed.sql (sellers are existing dummy alumni, looked up by
-- email) and on the marketplace migrations.
--
-- IDEMPOTENT: every listing has a fixed id and inserts use
-- ON CONFLICT (id) DO NOTHING, so running this twice changes nothing.
-- (Unlike seed_job_posts.sql, which duplicates on re-run.)
--
-- Note: seed rows are written directly as the database owner, so they skip
-- the "subscribers only" rule the app applies to new listings. Seed sellers
-- keep whatever subscription_status seed.sql gave them.
-- ============================================================================

insert into marketplace_listings
  (id, seller_id, title, description, price_idr, category, city, image_url,
   shop_url, contact_info, status, approved_at, created_at, updated_at)
select
  v.id::uuid,
  p.id,
  v.title,
  v.description,
  v.price_idr,
  v.category,
  v.city,
  'https://picsum.photos/seed/' || v.slug || '/600/400',
  v.shop_url,
  v.contact_info,
  v.status,
  case when v.status = 'approved' then now() - v.age else null end,
  now() - v.age,
  now() - v.age
from (values
  ('a0000000-0000-4000-8000-000000000001', 'bunga.ayu@example.com', 'mkt-kopi-lanang',
   'Kopi Arabika Temanggung 250 gr',
   'Biji kopi arabika petik merah dari lereng Sumbing, sangrai medium. Bisa digiling sesuai alat seduh. Contoh produk untuk demo.',
   85000, 'Food & Drink', 'Semarang', 'https://example.com/toko/kopi-lanang', null, 'approved', interval '9 days'),
  ('a0000000-0000-4000-8000-000000000002', 'dewi.sari@example.com', 'mkt-bolu-pandan',
   'Bolu Pandan Kukus Isi 12',
   'Bolu kukus pandan lembut, pesan H-1. Tersedia paket hampers untuk acara reuni. Contoh produk untuk demo.',
   65000, 'Food & Drink', 'Jakarta', null, 'WhatsApp: 0800-0000-0002 (nomor contoh)', 'approved', interval '8 days'),
  ('a0000000-0000-4000-8000-000000000003', 'ratna.dewi@example.com', 'mkt-batik-tulis',
   'Kemeja Batik Tulis Lasem Pria',
   'Kemeja batik tulis motif lasem, katun primisima, ukuran M sampai XXL. Contoh produk untuk demo.',
   450000, 'Fashion', 'Semarang', 'https://example.com/toko/batik-lasem', 'ratna.batik@example.com', 'approved', interval '8 days'),
  ('a0000000-0000-4000-8000-000000000004', 'nadia.lestari@example.com', 'mkt-tas-rotan',
   'Tas Rotan Anyaman Tangan',
   'Tas rotan anyaman tangan, cocok untuk kondangan maupun harian. Stok terbatas. Contoh produk untuk demo.',
   275000, 'Fashion', 'Yogyakarta', null, 'Email: nadia.tas@example.com', 'approved', interval '7 days'),
  ('a0000000-0000-4000-8000-000000000005', 'reza.putra@example.com', 'mkt-laptop-bekas',
   'Laptop Bekas Core i5 Gen 8, 8 GB RAM',
   'Laptop kantor bekas, baterai masih awet, sudah ganti SSD 256 GB. Bisa COD area Jakarta. Contoh produk untuk demo.',
   3750000, 'Electronics', 'Jakarta', null, 'Telepon: 0800-0000-0005 (nomor contoh)', 'approved', interval '6 days'),
  ('a0000000-0000-4000-8000-000000000006', 'ahmad.ramadhan@example.com', 'mkt-headset',
   'Headset Bluetooth Noise Cancelling',
   'Headset nirkabel dengan peredam bising, baterai 30 jam, garansi toko 6 bulan. Contoh produk untuk demo.',
   1500000, 'Electronics', 'Jakarta', 'https://example.com/toko/audio-ahmad', null, 'approved', interval '5 days'),
  ('a0000000-0000-4000-8000-000000000007', 'fajar.nugroho@example.com', 'mkt-jasa-pajak',
   'Jasa Pelaporan SPT Tahunan Pribadi',
   'Bantuan pengisian dan pelaporan SPT tahunan untuk karyawan dan freelancer. Konsultasi awal gratis. Contoh layanan untuk demo.',
   150000, 'Services', 'Jakarta', null, 'WhatsApp: 0800-0000-0007 (nomor contoh)', 'approved', interval '4 days'),
  ('a0000000-0000-4000-8000-000000000008', 'sari.permata@example.com', 'mkt-les-akuntansi',
   'Les Privat Akuntansi Dasar (online)',
   'Belajar jurnal, buku besar, dan laporan keuangan dari dasar. Sesi 90 menit lewat video call. Contoh layanan untuk demo.',
   120000, 'Services', 'Surabaya', 'https://example.com/toko/les-akuntansi', 'sari.les@example.com', 'approved', interval '3 days'),
  ('a0000000-0000-4000-8000-000000000009', 'kevin.halim@example.com', 'mkt-tanaman-hias',
   'Tanaman Hias Monstera Adansonii',
   'Monstera adansonii sehat dalam pot 15 cm, sudah berakar. Dikirim dengan packing kayu. Contoh produk untuk demo.',
   95000, 'Other', 'Semarang', null, 'WhatsApp: 0800-0000-0009 (nomor contoh)', 'approved', interval '2 days'),
  ('a0000000-0000-4000-8000-000000000010', 'melati.ningrum@example.com', 'mkt-buku-ekonomi',
   'Paket Buku Ekonomi Pembangunan (5 buku)',
   'Lima buku kuliah ekonomi pembangunan kondisi baik, tanpa coretan. Dijual satu paket. Contoh produk untuk demo.',
   200000, 'Other', 'Surabaya', null, 'Email: melati.buku@example.com', 'approved', interval '1 day'),
  ('a0000000-0000-4000-8000-000000000011', 'dimas.wicaksono@example.com', 'mkt-sambal-roa',
   'Sambal Roa Botol 200 ml',
   'Sambal roa pedas gurih tanpa pengawet, tahan 3 bulan di suhu ruang. Contoh produk untuk demo. Menunggu persetujuan admin.',
   55000, 'Food & Drink', 'Jakarta', 'https://example.com/toko/sambal-roa', null, 'pending', interval '6 hours'),
  ('a0000000-0000-4000-8000-000000000012', 'putri.maharani@example.com', 'mkt-desain-undangan',
   'Jasa Desain Undangan Digital',
   'Desain undangan pernikahan dan reuni digital, revisi 2 kali, jadi dalam 3 hari. Contoh layanan untuk demo. Menunggu persetujuan admin.',
   350000, 'Services', 'Jakarta', null, 'Instagram: @desain.contoh (akun contoh)', 'pending', interval '2 hours')
) as v(id, seller_email, slug, title, description, price_idr, category, city,
       shop_url, contact_info, status, age)
join alumni_profiles p on p.email = v.seller_email
on conflict (id) do nothing;

-- Demo admin: the project owner's own dummy-data profile from seed.sql.
-- Add more rows here (or in the dashboard) to make other profiles admins.
insert into marketplace_admins (profile_id)
select id from alumni_profiles where email = 'demo.admin@example.com'
on conflict (profile_id) do nothing;
