/// Cities offered in the product form dropdown. Plain names, sorted. The
/// first eight are the cities the app already uses for Nearby Alumni.
const List<String> kMarketplaceCities = [
  'Balikpapan',
  'Bandar Lampung',
  'Bandung',
  'Banjarmasin',
  'Batam',
  'Bekasi',
  'Bogor',
  'Cirebon',
  'Denpasar',
  'Depok',
  'Jakarta',
  'Jambi',
  'Makassar',
  'Malang',
  'Manado',
  'Medan',
  'Padang',
  'Palembang',
  'Pekanbaru',
  'Pontianak',
  'Samarinda',
  'Semarang',
  'Solo',
  'Surabaya',
  'Tangerang',
  'Yogyakarta',
];

/// [kMarketplaceCities], plus [current] when it is set and not in the list
/// (an older product keeps the city it was saved with).
List<String> citiesWith(String? current) {
  final c = (current ?? '').trim();
  if (c.isEmpty || kMarketplaceCities.contains(c)) return kMarketplaceCities;
  return [...kMarketplaceCities, c]..sort();
}
