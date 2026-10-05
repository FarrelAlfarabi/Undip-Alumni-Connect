import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';

/// verification_status is set by the verify_alumni_email() function only (see
/// 20261005090000_lock_verification_status.sql). The app must not write it.
void main() {
  group('profileFromVerifyResult', () {
    test('a verified row comes back as the profile', () {
      final row = {
        'id': 'a',
        'name': 'Siti',
        'verification_status': 'verified',
      };
      expect(profileFromVerifyResult([row]), row);
    });

    test('no rows means no match', () {
      expect(profileFromVerifyResult(<dynamic>[]), isNull);
      expect(profileFromVerifyResult(null), isNull);
    });

    test('a failed (revoked) person is not let in', () {
      final row = {'id': 'a', 'verification_status': 'failed'};
      expect(profileFromVerifyResult([row]), isNull);
    });

    test('an unverified row is not let in', () {
      final row = {'id': 'a', 'verification_status': 'unverified'};
      expect(profileFromVerifyResult([row]), isNull);
    });

    test('a single map (not a list) is accepted too', () {
      final row = {'id': 'a', 'verification_status': 'verified'};
      expect(profileFromVerifyResult(row), row);
    });
  });

  test('no screen or repository writes verification_status', () {
    final offenders = <String>[];
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      if (RegExp(r"\.update\(\s*\{[^}]*verification_status").hasMatch(text)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('the verify screen calls the server function', () {
    final text = File('lib/screens/verification_screen.dart')
        .readAsStringSync();
    expect(RegExp(r"rpc\(\s*'verify_alumni_email'").hasMatch(text), isTrue);
  });
}
