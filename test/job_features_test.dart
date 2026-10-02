import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/application_status.dart';
import 'package:undip_alumni_connect/data/indonesia_cities.dart';

void main() {
  test('city list has no duplicates and keeps the seeded cities', () {
    expect(kIndonesiaCities.toSet().length, kIndonesiaCities.length);
    for (final city in ['Jakarta', 'Semarang', 'Surabaya', 'Makassar']) {
      expect(kIndonesiaCities, contains(city));
    }
  });

  test('every status has a label and unknown falls back to Pending', () {
    for (final status in ApplicationStatus.all) {
      expect(ApplicationStatus.label(status), isNotEmpty);
    }
    expect(ApplicationStatus.label(null), 'Pending');
    expect(ApplicationStatus.label('weird'), 'Pending');
  });
}
