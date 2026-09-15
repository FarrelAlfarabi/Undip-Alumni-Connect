-- ============================================================================
-- Seed data — UNDIP Alumni Connect MVP demo
--
-- DEMO SCOPE NOTICE: dummy data only, no real alumni. Verification for the
-- demo is a plain exact-string-match against alumni_profiles.email — see
-- the "DEMO VERIFICATION TEST EMAILS" list below for the ones to use when
-- demoing the signup flow. (Scope change 14 Sep, post-Gilang meeting:
-- verification switched from NIM exact-match to email exact-match. nim
-- values are kept below as a real profile field, just no longer the
-- verification key.)
--
-- Idempotent: safe to re-run. ON CONFLICT (nim) DO UPDATE SET email so
-- that re-running this script against the already-seeded live project
-- backfills email on the 24 existing rows instead of skipping them.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DEMO VERIFICATION TEST EMAILS
-- Use any of these at signup to exercise the exact-match "verified" path.
-- Any email not in this table will exact-match-fail, demonstrating the
-- unverified/rejected path. Same 5 rows as the old NIM test list.
--
-- All 5 seed as subscription_status = 'free' on purpose (fixed 15 Sep,
-- Day 9 walkthrough — they were originally seeded 'subscribed', which
-- meant following this exact demo script never showed the paywall at
-- all). Use one of these to demo the locked → Subscribe → unlocked flow
-- live. bunga.ayu@example.com is left 'subscribed' if you want to show
-- what an already-subscribed profile looks like without subscribing live.
--
--   ahmad.ramadhan@example.com   Ahmad Fauzan Ramadhan   (Teknik Informatika, 2023)
--   siti.azizah@example.com      Siti Nur Azizah         (Manajemen, 2022)
--   bagas.prasetyo@example.com   Bagas Dwi Prasetyo      (Ilmu Hukum, 2021)
--   clara.putri@example.com      Clara Amelia Putri      (Pendidikan Dokter, 2020)
--   rizky.yusuf@example.com      Rizky Maulana Yusuf     (Ilmu Komunikasi, 2019)
-- ----------------------------------------------------------------------------

insert into alumni_profiles
  (nim, name, faculty, major, graduation_year, current_employer, "current_role", industry, company, verification_status, subscription_status, email)
values
  -- Fakultas Teknik
  ('24010119130001', 'Ahmad Fauzan Ramadhan', 'Fakultas Teknik', 'Teknik Informatika', 2023, 'Gojek', 'Software Engineer', 'Technology', 'Gojek', 'verified', 'free', 'ahmad.ramadhan@example.com'),
  ('24010118130006', 'Dewi Kartika Sari', 'Fakultas Teknik', 'Teknik Sipil', 2022, 'PT Wijaya Karya', 'Site Engineer', 'Construction', 'PT Wijaya Karya', 'verified', 'free', 'dewi.sari@example.com'),
  ('24010117130007', 'Muhammad Iqbal Hakim', 'Fakultas Teknik', 'Teknik Elektro', 2021, 'PLN', 'Electrical Engineer', 'Energy', 'PLN', 'verified', 'free', 'muhammad.hakim@example.com'),

  -- Fakultas Ekonomika dan Bisnis
  ('24020118130002', 'Siti Nur Azizah', 'Fakultas Ekonomika dan Bisnis', 'Manajemen', 2022, 'Bank Mandiri', 'Relationship Manager', 'Banking & Finance', 'Bank Mandiri', 'verified', 'free', 'siti.azizah@example.com'),
  ('24020117130008', 'Fajar Nugroho', 'Fakultas Ekonomika dan Bisnis', 'Akuntansi', 2021, 'Deloitte Indonesia', 'Audit Associate', 'Consulting', 'Deloitte Indonesia', 'verified', 'free', 'fajar.nugroho@example.com'),
  ('24020116130009', 'Ratna Puspita Dewi', 'Fakultas Ekonomika dan Bisnis', 'Ilmu Ekonomi dan Studi Pembangunan', 2020, 'Bank Indonesia', 'Economist', 'Banking & Finance', 'Bank Indonesia', 'verified', 'free', 'ratna.dewi@example.com'),

  -- Fakultas Hukum
  ('24030117130003', 'Bagas Dwi Prasetyo', 'Fakultas Hukum', 'Ilmu Hukum', 2021, 'Hutama & Rekan Law Firm', 'Junior Associate', 'Legal Services', 'Hutama & Rekan Law Firm', 'verified', 'free', 'bagas.prasetyo@example.com'),
  ('24030116130010', 'Intan Permatasari', 'Fakultas Hukum', 'Ilmu Hukum', 2020, 'Kementerian Hukum dan HAM', 'Legal Analyst', 'Government', 'Kementerian Hukum dan HAM', 'verified', 'free', 'intan.permatasari@example.com'),

  -- Fakultas Kedokteran
  ('24040116130004', 'Clara Amelia Putri', 'Fakultas Kedokteran', 'Pendidikan Dokter', 2020, 'RSUP Dr. Kariadi', 'General Practitioner', 'Healthcare', 'RSUP Dr. Kariadi', 'verified', 'free', 'clara.putri@example.com'),
  ('24040115130011', 'Yusuf Ardiansyah', 'Fakultas Kedokteran', 'Pendidikan Dokter', 2019, 'RS Telogorejo', 'Resident Physician', 'Healthcare', 'RS Telogorejo', 'verified', 'free', 'yusuf.ardiansyah@example.com'),

  -- Fakultas Ilmu Budaya
  ('24050115130005', 'Rizky Maulana Yusuf', 'Fakultas Ilmu Budaya', 'Ilmu Komunikasi', 2019, 'Kompas Gramedia', 'Content Producer', 'Media', 'Kompas Gramedia', 'verified', 'free', 'rizky.yusuf@example.com'),
  ('24050114130012', 'Anggita Sekar Wulandari', 'Fakultas Ilmu Budaya', 'Sastra Inggris', 2018, 'British Council Indonesia', 'Program Officer', 'Education', 'British Council Indonesia', 'verified', 'free', 'anggita.wulandari@example.com'),

  -- Fakultas Sains dan Matematika
  ('24060114130013', 'Reza Pratama Putra', 'Fakultas Sains dan Matematika', 'Ilmu Komputer', 2018, 'Tokopedia', 'Data Analyst', 'Technology', 'Tokopedia', 'verified', 'free', 'reza.putra@example.com'),
  ('24060113130014', 'Nadia Ayu Lestari', 'Fakultas Sains dan Matematika', 'Statistika', 2017, 'Badan Pusat Statistik', 'Statistician', 'Government', 'Badan Pusat Statistik', 'verified', 'free', 'nadia.lestari@example.com'),

  -- Fakultas Peternakan dan Pertanian
  ('24070113130015', 'Andika Saputra', 'Fakultas Peternakan dan Pertanian', 'Agribisnis', 2017, 'PT Charoen Pokphand Indonesia', 'Field Supervisor', 'Agriculture', 'PT Charoen Pokphand Indonesia', 'verified', 'free', 'andika.saputra@example.com'),
  ('24070112130016', 'Melati Ayu Ningrum', 'Fakultas Peternakan dan Pertanian', 'Peternakan', 2016, 'PT Japfa Comfeed Indonesia', 'Production Officer', 'Agriculture', 'PT Japfa Comfeed Indonesia', 'verified', 'free', 'melati.ningrum@example.com'),

  -- Fakultas Psikologi
  ('24080112130017', 'Bunga Citra Ayu', 'Fakultas Psikologi', 'Psikologi', 2016, 'Prudential Indonesia', 'HR Business Partner', 'Human Resources', 'Prudential Indonesia', 'verified', 'subscribed', 'bunga.ayu@example.com'),
  ('24080111130018', 'Dimas Aryo Wicaksono', 'Fakultas Psikologi', 'Psikologi', 2015, 'Unilever Indonesia', 'Talent Acquisition Specialist', 'Human Resources', 'Unilever Indonesia', 'verified', 'free', 'dimas.wicaksono@example.com'),

  -- Fakultas Ilmu Sosial dan Ilmu Politik
  ('24090111130019', 'Kevin Alexander Halim', 'Fakultas Ilmu Sosial dan Ilmu Politik', 'Ilmu Pemerintahan', 2015, 'Pemerintah Kota Semarang', 'Staff Ahli', 'Government', 'Pemerintah Kota Semarang', 'verified', 'free', 'kevin.halim@example.com'),
  ('24090110130020', 'Putri Ayu Maharani', 'Fakultas Ilmu Sosial dan Ilmu Politik', 'Hubungan Internasional', 2014, 'Kementerian Luar Negeri', 'Diplomat Muda', 'Government', 'Kementerian Luar Negeri', 'verified', 'free', 'putri.maharani@example.com'),

  -- Fakultas Kesehatan Masyarakat
  ('24100110130021', 'Aditya Kurniawan', 'Fakultas Kesehatan Masyarakat', 'Kesehatan Masyarakat', 2014, 'WHO Indonesia', 'Public Health Officer', 'Healthcare', 'WHO Indonesia', 'verified', 'free', 'aditya.kurniawan@example.com'),
  ('24100109130022', 'Sari Indah Permata', 'Fakultas Kesehatan Masyarakat', 'Gizi Kesehatan', 2013, 'Nestle Indonesia', 'Nutrition Specialist', 'Manufacturing', 'Nestle Indonesia', 'verified', 'free', 'sari.permata@example.com'),

  -- Fakultas Perikanan dan Ilmu Kelautan
  ('24110109130023', 'Fahmi Ridho Alamsyah', 'Fakultas Perikanan dan Ilmu Kelautan', 'Manajemen Sumberdaya Perairan', 2013, 'Kementerian Kelautan dan Perikanan', 'Marine Researcher', 'Government', 'Kementerian Kelautan dan Perikanan', 'verified', 'free', 'fahmi.alamsyah@example.com'),

  -- Sekolah Vokasi
  ('24120108130024', 'Vina Angelina Tan', 'Sekolah Vokasi', 'Manajemen Perkantoran', 2012, 'Astra International', 'Executive Assistant', 'Manufacturing', 'Astra International', 'verified', 'free', 'vina.tan@example.com')
on conflict (nim) do update set email = excluded.email;

-- ----------------------------------------------------------------------------
-- Demo account for the project owner — real email, made-up profile details
-- (employer/role/etc. are fabricated for the demo, not real information).
-- Use this email to log in as "yourself" when demoing.
-- ----------------------------------------------------------------------------
insert into alumni_profiles
  (nim, name, faculty, major, graduation_year, current_employer, "current_role", industry, company, verification_status, subscription_status, email)
values
  ('24010119130099', 'Farrel Alfarabi Saleh', 'Fakultas Teknik', 'Teknik Informatika', 2020, 'Bank Central Asia', 'Product Manager', 'Banking & Finance', 'Bank Central Asia', 'verified', 'free', 'farrel.abi.saleh@gmail.com')
on conflict (nim) do update set email = excluded.email;

-- ----------------------------------------------------------------------------
-- Demo account for Gilang (ILUNI UNDIP) — real email, made-up profile
-- details (employer/role/etc. are fabricated for the demo). Lets him log
-- in as a seeded alumnus during the live demo if he wants to try it
-- himself, rather than only watching over screen-share.
-- ----------------------------------------------------------------------------
insert into alumni_profiles
  (nim, name, faculty, major, graduation_year, current_employer, "current_role", industry, company, verification_status, subscription_status, email)
values
  ('24020110130098', 'Gilang Ramadhan Wibowo', 'Fakultas Ekonomika dan Bisnis', 'Manajemen', 2010, 'ILUNI UNDIP', 'Ketua Umum', 'Nonprofit / Alumni Association', 'ILUNI UNDIP', 'verified', 'free', 'gilang.modcart@gmail.com')
on conflict (nim) do update set email = excluded.email;

-- Note: the non-matching signup path needs no seed data — any email that
-- isn't one of the 25 above already demonstrates "not found."

-- ----------------------------------------------------------------------------
-- Cities — powers the Nearby Alumni demo feature (see
-- 20260916090000_add_alumni_city.sql for why this is simulated, not real
-- GPS). Roughly matches each alumnus's seeded employer's real city.
-- ----------------------------------------------------------------------------
alter table alumni_profiles disable trigger alumni_profiles_restrict_update_trigger;

update alumni_profiles set city = case email
  when 'ahmad.ramadhan@example.com' then 'Jakarta'
  when 'dewi.sari@example.com' then 'Jakarta'
  when 'muhammad.hakim@example.com' then 'Semarang'
  when 'siti.azizah@example.com' then 'Jakarta'
  when 'fajar.nugroho@example.com' then 'Jakarta'
  when 'ratna.dewi@example.com' then 'Jakarta'
  when 'bagas.prasetyo@example.com' then 'Semarang'
  when 'intan.permatasari@example.com' then 'Jakarta'
  when 'clara.putri@example.com' then 'Semarang'
  when 'yusuf.ardiansyah@example.com' then 'Semarang'
  when 'rizky.yusuf@example.com' then 'Jakarta'
  when 'anggita.wulandari@example.com' then 'Jakarta'
  when 'reza.putra@example.com' then 'Jakarta'
  when 'nadia.lestari@example.com' then 'Jakarta'
  when 'andika.saputra@example.com' then 'Semarang'
  when 'melati.ningrum@example.com' then 'Surabaya'
  when 'bunga.ayu@example.com' then 'Jakarta'
  when 'dimas.wicaksono@example.com' then 'Jakarta'
  when 'kevin.halim@example.com' then 'Semarang'
  when 'putri.maharani@example.com' then 'Jakarta'
  when 'aditya.kurniawan@example.com' then 'Jakarta'
  when 'sari.permata@example.com' then 'Jakarta'
  when 'fahmi.alamsyah@example.com' then 'Semarang'
  when 'vina.tan@example.com' then 'Jakarta'
  when 'farrel.abi.saleh@gmail.com' then 'Yogyakarta'
  when 'gilang.modcart@gmail.com' then 'Jakarta'
end
where email in (
  'ahmad.ramadhan@example.com','dewi.sari@example.com','muhammad.hakim@example.com',
  'siti.azizah@example.com','fajar.nugroho@example.com','ratna.dewi@example.com',
  'bagas.prasetyo@example.com','intan.permatasari@example.com','clara.putri@example.com',
  'yusuf.ardiansyah@example.com','rizky.yusuf@example.com','anggita.wulandari@example.com',
  'reza.putra@example.com','nadia.lestari@example.com','andika.saputra@example.com',
  'melati.ningrum@example.com','bunga.ayu@example.com','dimas.wicaksono@example.com',
  'kevin.halim@example.com','putri.maharani@example.com','aditya.kurniawan@example.com',
  'sari.permata@example.com','fahmi.alamsyah@example.com','vina.tan@example.com',
  'farrel.abi.saleh@gmail.com','gilang.modcart@gmail.com'
);

alter table alumni_profiles enable trigger alumni_profiles_restrict_update_trigger;
