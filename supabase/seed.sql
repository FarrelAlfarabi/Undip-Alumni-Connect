-- ============================================================================
-- Seed data — UNDIP Alumni Connect MVP demo
--
-- DEMO SCOPE NOTICE: dummy data only, no real alumni. NIM verification for
-- the demo is a plain exact-string-match against alumni_profiles.nim — see
-- the "DEMO VERIFICATION TEST NIMs" list below for the ones to use when
-- demoing the signup flow.
--
-- Idempotent: safe to re-run (ON CONFLICT DO NOTHING keyed on nim).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DEMO VERIFICATION TEST NIMs
-- Use any of these at signup to exercise the exact-match "verified" path.
-- Any NIM not in this table will exact-match-fail, demonstrating the
-- unverified/rejected path.
--
--   24010119130001  Ahmad Fauzan Ramadhan   (Teknik Informatika, 2023)
--   24020118130002  Siti Nur Azizah         (Manajemen, 2022)
--   24030117130003  Bagas Dwi Prasetyo      (Ilmu Hukum, 2021)
--   24040116130004  Clara Amelia Putri      (Pendidikan Dokter, 2020)
--   24050115130005  Rizky Maulana Yusuf     (Ilmu Komunikasi, 2019)
-- ----------------------------------------------------------------------------

insert into alumni_profiles
  (nim, name, faculty, major, graduation_year, current_employer, "current_role", industry, company, verification_status, subscription_status)
values
  -- Fakultas Teknik
  ('24010119130001', 'Ahmad Fauzan Ramadhan', 'Fakultas Teknik', 'Teknik Informatika', 2023, 'Gojek', 'Software Engineer', 'Technology', 'Gojek', 'verified', 'subscribed'),
  ('24010118130006', 'Dewi Kartika Sari', 'Fakultas Teknik', 'Teknik Sipil', 2022, 'PT Wijaya Karya', 'Site Engineer', 'Construction', 'PT Wijaya Karya', 'verified', 'free'),
  ('24010117130007', 'Muhammad Iqbal Hakim', 'Fakultas Teknik', 'Teknik Elektro', 2021, 'PLN', 'Electrical Engineer', 'Energy', 'PLN', 'verified', 'free'),

  -- Fakultas Ekonomika dan Bisnis
  ('24020118130002', 'Siti Nur Azizah', 'Fakultas Ekonomika dan Bisnis', 'Manajemen', 2022, 'Bank Mandiri', 'Relationship Manager', 'Banking & Finance', 'Bank Mandiri', 'verified', 'subscribed'),
  ('24020117130008', 'Fajar Nugroho', 'Fakultas Ekonomika dan Bisnis', 'Akuntansi', 2021, 'Deloitte Indonesia', 'Audit Associate', 'Consulting', 'Deloitte Indonesia', 'verified', 'free'),
  ('24020116130009', 'Ratna Puspita Dewi', 'Fakultas Ekonomika dan Bisnis', 'Ilmu Ekonomi dan Studi Pembangunan', 2020, 'Bank Indonesia', 'Economist', 'Banking & Finance', 'Bank Indonesia', 'verified', 'free'),

  -- Fakultas Hukum
  ('24030117130003', 'Bagas Dwi Prasetyo', 'Fakultas Hukum', 'Ilmu Hukum', 2021, 'Hutama & Rekan Law Firm', 'Junior Associate', 'Legal Services', 'Hutama & Rekan Law Firm', 'verified', 'subscribed'),
  ('24030116130010', 'Intan Permatasari', 'Fakultas Hukum', 'Ilmu Hukum', 2020, 'Kementerian Hukum dan HAM', 'Legal Analyst', 'Government', 'Kementerian Hukum dan HAM', 'verified', 'free'),

  -- Fakultas Kedokteran
  ('24040116130004', 'Clara Amelia Putri', 'Fakultas Kedokteran', 'Pendidikan Dokter', 2020, 'RSUP Dr. Kariadi', 'General Practitioner', 'Healthcare', 'RSUP Dr. Kariadi', 'verified', 'subscribed'),
  ('24040115130011', 'Yusuf Ardiansyah', 'Fakultas Kedokteran', 'Pendidikan Dokter', 2019, 'RS Telogorejo', 'Resident Physician', 'Healthcare', 'RS Telogorejo', 'verified', 'free'),

  -- Fakultas Ilmu Budaya
  ('24050115130005', 'Rizky Maulana Yusuf', 'Fakultas Ilmu Budaya', 'Ilmu Komunikasi', 2019, 'Kompas Gramedia', 'Content Producer', 'Media', 'Kompas Gramedia', 'verified', 'subscribed'),
  ('24050114130012', 'Anggita Sekar Wulandari', 'Fakultas Ilmu Budaya', 'Sastra Inggris', 2018, 'British Council Indonesia', 'Program Officer', 'Education', 'British Council Indonesia', 'verified', 'free'),

  -- Fakultas Sains dan Matematika
  ('24060114130013', 'Reza Pratama Putra', 'Fakultas Sains dan Matematika', 'Ilmu Komputer', 2018, 'Tokopedia', 'Data Analyst', 'Technology', 'Tokopedia', 'verified', 'free'),
  ('24060113130014', 'Nadia Ayu Lestari', 'Fakultas Sains dan Matematika', 'Statistika', 2017, 'Badan Pusat Statistik', 'Statistician', 'Government', 'Badan Pusat Statistik', 'verified', 'free'),

  -- Fakultas Peternakan dan Pertanian
  ('24070113130015', 'Andika Saputra', 'Fakultas Peternakan dan Pertanian', 'Agribisnis', 2017, 'PT Charoen Pokphand Indonesia', 'Field Supervisor', 'Agriculture', 'PT Charoen Pokphand Indonesia', 'verified', 'free'),
  ('24070112130016', 'Melati Ayu Ningrum', 'Fakultas Peternakan dan Pertanian', 'Peternakan', 2016, 'PT Japfa Comfeed Indonesia', 'Production Officer', 'Agriculture', 'PT Japfa Comfeed Indonesia', 'verified', 'free'),

  -- Fakultas Psikologi
  ('24080112130017', 'Bunga Citra Ayu', 'Fakultas Psikologi', 'Psikologi', 2016, 'Prudential Indonesia', 'HR Business Partner', 'Human Resources', 'Prudential Indonesia', 'verified', 'subscribed'),
  ('24080111130018', 'Dimas Aryo Wicaksono', 'Fakultas Psikologi', 'Psikologi', 2015, 'Unilever Indonesia', 'Talent Acquisition Specialist', 'Human Resources', 'Unilever Indonesia', 'verified', 'free'),

  -- Fakultas Ilmu Sosial dan Ilmu Politik
  ('24090111130019', 'Kevin Alexander Halim', 'Fakultas Ilmu Sosial dan Ilmu Politik', 'Ilmu Pemerintahan', 2015, 'Pemerintah Kota Semarang', 'Staff Ahli', 'Government', 'Pemerintah Kota Semarang', 'verified', 'free'),
  ('24090110130020', 'Putri Ayu Maharani', 'Fakultas Ilmu Sosial dan Ilmu Politik', 'Hubungan Internasional', 2014, 'Kementerian Luar Negeri', 'Diplomat Muda', 'Government', 'Kementerian Luar Negeri', 'verified', 'free'),

  -- Fakultas Kesehatan Masyarakat
  ('24100110130021', 'Aditya Kurniawan', 'Fakultas Kesehatan Masyarakat', 'Kesehatan Masyarakat', 2014, 'WHO Indonesia', 'Public Health Officer', 'Healthcare', 'WHO Indonesia', 'verified', 'free'),
  ('24100109130022', 'Sari Indah Permata', 'Fakultas Kesehatan Masyarakat', 'Gizi Kesehatan', 2013, 'Nestle Indonesia', 'Nutrition Specialist', 'Manufacturing', 'Nestle Indonesia', 'verified', 'free'),

  -- Fakultas Perikanan dan Ilmu Kelautan
  ('24110109130023', 'Fahmi Ridho Alamsyah', 'Fakultas Perikanan dan Ilmu Kelautan', 'Manajemen Sumberdaya Perairan', 2013, 'Kementerian Kelautan dan Perikanan', 'Marine Researcher', 'Government', 'Kementerian Kelautan dan Perikanan', 'verified', 'free'),

  -- Sekolah Vokasi
  ('24120108130024', 'Vina Angelina Tan', 'Sekolah Vokasi', 'Manajemen Perkantoran', 2012, 'Astra International', 'Executive Assistant', 'Manufacturing', 'Astra International', 'verified', 'free')
on conflict (nim) do nothing;

-- Note: the non-matching signup path needs no seed data — any NIM that
-- isn't one of the 24 above already demonstrates "not found."
