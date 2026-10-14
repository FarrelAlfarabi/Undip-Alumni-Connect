/// Every Indonesian city (kota), with an approximate centre point
/// (latitude, longitude). Used by the city pickers and, for pairs that have
/// no hand-entered distance, to work out the Nearby demo distance.
///
/// Coordinates are rounded to two decimals: good enough for "about N km".
const Map<String, (double, double)> _indonesianCities = {
  // Aceh
  'Banda Aceh': (5.55, 95.32),
  'Langsa': (4.47, 97.97),
  'Lhokseumawe': (5.18, 97.15),
  'Sabang': (5.89, 95.32),
  'Subulussalam': (2.65, 98.00),
  // Sumatera Utara
  'Binjai': (3.60, 98.49),
  'Gunungsitoli': (1.29, 97.61),
  'Medan': (3.59, 98.67),
  'Padang Sidempuan': (1.38, 99.27),
  'Pematangsiantar': (2.96, 99.06),
  'Sibolga': (1.74, 98.78),
  'Tanjungbalai': (2.97, 99.80),
  'Tebing Tinggi': (3.33, 99.16),
  // Sumatera Barat
  'Bukittinggi': (-0.31, 100.37),
  'Padang': (-0.95, 100.35),
  'Padang Panjang': (-0.47, 100.40),
  'Pariaman': (-0.63, 100.12),
  'Payakumbuh': (-0.23, 100.63),
  'Sawahlunto': (-0.68, 100.78),
  'Solok': (-0.79, 100.65),
  // Riau, Kepulauan Riau
  'Dumai': (1.67, 101.45),
  'Pekanbaru': (0.51, 101.45),
  'Batam': (1.05, 104.03),
  'Tanjungpinang': (0.92, 104.45),
  // Jambi, Sumatera Selatan, Bengkulu, Bangka Belitung, Lampung
  'Jambi': (-1.61, 103.61),
  'Sungai Penuh': (-2.06, 101.39),
  'Lubuklinggau': (-3.30, 102.86),
  'Pagar Alam': (-4.03, 103.25),
  'Palembang': (-2.98, 104.76),
  'Prabumulih': (-3.43, 104.24),
  'Bengkulu': (-3.80, 102.26),
  'Pangkal Pinang': (-2.13, 106.11),
  'Bandar Lampung': (-5.43, 105.26),
  'Metro': (-5.11, 105.31),
  // Banten, DKI Jakarta
  'Cilegon': (-6.00, 106.02),
  'Serang': (-6.12, 106.15),
  'Tangerang': (-6.18, 106.63),
  'Tangerang Selatan': (-6.29, 106.72),
  'Jakarta': (-6.21, 106.85),
  // Jawa Barat
  'Bandung': (-6.92, 107.61),
  'Banjar': (-7.37, 108.54),
  'Bekasi': (-6.24, 106.99),
  'Bogor': (-6.60, 106.80),
  'Cimahi': (-6.87, 107.54),
  'Cirebon': (-6.71, 108.56),
  'Depok': (-6.40, 106.82),
  'Sukabumi': (-6.92, 106.93),
  'Tasikmalaya': (-7.33, 108.22),
  // Jawa Tengah, DI Yogyakarta
  'Magelang': (-7.47, 110.22),
  'Pekalongan': (-6.89, 109.68),
  'Salatiga': (-7.33, 110.50),
  'Semarang': (-6.97, 110.42),
  'Solo (Surakarta)': (-7.57, 110.82),
  'Tegal': (-6.87, 109.14),
  'Yogyakarta': (-7.80, 110.36),
  // Jawa Timur
  'Batu': (-7.87, 112.53),
  'Blitar': (-8.10, 112.17),
  'Kediri': (-7.82, 112.01),
  'Madiun': (-7.63, 111.52),
  'Malang': (-7.98, 112.63),
  'Mojokerto': (-7.47, 112.43),
  'Pasuruan': (-7.65, 112.91),
  'Probolinggo': (-7.75, 113.22),
  'Surabaya': (-7.25, 112.75),
  // Bali, Nusa Tenggara
  'Denpasar': (-8.65, 115.22),
  'Bima': (-8.46, 118.73),
  'Mataram': (-8.58, 116.12),
  'Kupang': (-10.18, 123.60),
  // Kalimantan
  'Pontianak': (-0.03, 109.33),
  'Singkawang': (0.91, 108.98),
  'Palangka Raya': (-2.21, 113.92),
  'Banjarbaru': (-3.44, 114.83),
  'Banjarmasin': (-3.32, 114.59),
  'Balikpapan': (-1.24, 116.83),
  'Bontang': (0.13, 117.50),
  'Samarinda': (-0.50, 117.15),
  'Tarakan': (3.30, 117.63),
  // Sulawesi
  'Bitung': (1.44, 125.19),
  'Kotamobagu': (0.73, 124.31),
  'Manado': (1.47, 124.84),
  'Tomohon': (1.32, 124.84),
  'Gorontalo': (0.54, 123.06),
  'Palu': (-0.90, 119.87),
  'Makassar': (-5.15, 119.43),
  'Palopo': (-3.00, 120.20),
  'Parepare': (-4.01, 119.62),
  'Baubau': (-5.47, 122.63),
  'Kendari': (-3.97, 122.51),
  // Maluku, Papua
  'Ambon': (-3.70, 128.18),
  'Tual': (-5.64, 132.75),
  'Ternate': (0.79, 127.38),
  'Tidore': (0.68, 127.43),
  'Jayapura': (-2.53, 140.72),
  'Sorong': (-0.88, 131.26),
};

/// All city names, sorted A to Z.
final List<String> kIndonesianCities = _indonesianCities.keys.toList()..sort();

/// Centre point of [city], or null when it isn't in the list.
(double, double)? cityCoordinates(String? city) => _indonesianCities[city];
