import 'indonesian_cities.dart';

/// Cities offered in the product form dropdown: every Indonesian city.
final List<String> kMarketplaceCities = kIndonesianCities;

/// [kMarketplaceCities], plus [current] when it is set and not in the list
/// (an older product keeps the city it was saved with).
List<String> citiesWith(String? current) {
  final c = (current ?? '').trim();
  if (c.isEmpty || kMarketplaceCities.contains(c)) return kMarketplaceCities;
  return [...kMarketplaceCities, c]..sort();
}
