/// Indonesian cities for the city pickers: every kota (Jakarta as one
/// entry) plus the kabupaten (regencies) and towns where business and
/// alumni are concentrated.
/// Bare names, as people write them ("Semarang", "Jakarta"); a regency
/// that shares a name with a city is written "Kabupaten X" so the two
/// stay distinct.
///
/// Static list on purpose: it changes about once a decade, and a picker
/// that needs the network to open is worse than one that is a little
/// stale. Not every kabupaten is here; add one to the list if it is missed.
const List<String> kIndonesiaCities = [
  // Aceh
  'Banda Aceh', 'Langsa', 'Lhokseumawe', 'Sabang', 'Subulussalam',
  // Sumatera Utara
  'Binjai', 'Gunungsitoli', 'Kabupaten Deli Serdang', 'Medan',
  'Padang Sidempuan', 'Pematangsiantar', 'Sibolga', 'Tanjungbalai',
  'Tebing Tinggi',
  // Sumatera Barat
  'Bukittinggi', 'Padang', 'Padang Panjang', 'Pariaman', 'Payakumbuh',
  'Sawahlunto', 'Solok',
  // Riau and Kepulauan Riau
  'Batam', 'Dumai', 'Pekanbaru', 'Tanjungpinang',
  // Jambi, Sumatera Selatan, Bengkulu, Lampung, Bangka Belitung
  'Bandar Lampung', 'Bengkulu', 'Jambi', 'Lubuklinggau', 'Metro',
  'Pagar Alam', 'Palembang', 'Pangkal Pinang', 'Prabumulih', 'Sungai Penuh',
  // Banten
  'Cilegon', 'Kabupaten Tangerang', 'Serang', 'Tangerang',
  'Tangerang Selatan',
  // DKI Jakarta
  'Jakarta',
  // Jawa Barat
  'Bandung', 'Banjar', 'Bekasi', 'Bogor', 'Cimahi', 'Cirebon', 'Depok',
  'Kabupaten Bandung', 'Kabupaten Bekasi', 'Kabupaten Bogor',
  'Kabupaten Karawang', 'Sukabumi', 'Tasikmalaya',
  // Jawa Tengah
  'Kabupaten Semarang', 'Kudus', 'Magelang', 'Pekalongan', 'Purwokerto',
  'Salatiga', 'Semarang', 'Surakarta', 'Tegal',
  // DI Yogyakarta
  'Sleman', 'Yogyakarta',
  // Jawa Timur
  'Batu', 'Blitar', 'Gresik', 'Kediri', 'Madiun', 'Malang', 'Mojokerto',
  'Pasuruan', 'Probolinggo', 'Sidoarjo', 'Surabaya',
  // Bali, Nusa Tenggara
  'Badung', 'Bima', 'Denpasar', 'Gianyar', 'Kupang', 'Mataram',
  // Kalimantan
  'Balikpapan', 'Banjarbaru', 'Banjarmasin', 'Bontang', 'Palangka Raya',
  'Pontianak', 'Samarinda', 'Singkawang', 'Tarakan',
  // Sulawesi
  'Baubau', 'Bitung', 'Gorontalo', 'Kendari', 'Kotamobagu', 'Makassar',
  'Manado', 'Palopo', 'Palu', 'Parepare', 'Tomohon',
  // Maluku and Papua
  'Ambon', 'Jayapura', 'Merauke', 'Sorong', 'Ternate', 'Tidore Kepulauan',
  'Tual',
];
