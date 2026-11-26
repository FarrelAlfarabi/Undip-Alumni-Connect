import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/util/strings_id.dart';

void main() {
  test('texts found in the UI test have Indonesian copy', () {
    for (final key in [
      'Graduation Year',
      'No open reports.',
      'Nothing is hidden.',
      'Faculty',
      'Major',
      'Current Role',
      'Industry',
      'Company',
      'Reports',
      'Hidden items',
    ]) {
      expect(kIndonesian[key], isNotNull, reason: key);
    }
  });
}
