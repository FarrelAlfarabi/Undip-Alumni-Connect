import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/policy_config.dart';

/// Gate for anything handed to testers. The two groups below differ:
///  * 'detector' always runs and proves the check itself works.
///  * 'release gate' runs only with --dart-define=RELEASE_CHECK=true (the CI
///    APK job does this) and fails while a placeholder is left in the policy.
/// Day to day `flutter test` stays green while the values are still unfilled.
const bool _releaseCheck = bool.fromEnvironment('RELEASE_CHECK');

void main() {
  group('detector', () {
    test('finds an unfilled placeholder', () {
      expect(hasPolicyPlaceholder('[FILL IN: operator name]'), isTrue);
      expect(hasPolicyPlaceholder('PT Contoh [FILL IN: x]'), isTrue);
    });

    test('accepts real values', () {
      expect(hasPolicyPlaceholder('Ikafe FEB UNDIP'), isFalse);
      expect(hasPolicyPlaceholder('admin@example.org'), isFalse);
    });

    test('an empty value counts as unfilled', () {
      expect(hasPolicyPlaceholder(''), isTrue);
      expect(hasPolicyPlaceholder('   '), isTrue);
    });
  });

  group('release gate', () {
    const skipReason = _releaseCheck
        ? null
        : 'only with --dart-define=RELEASE_CHECK=true';

    test('operator name, contact email and address are filled in', () {
      expect(
        hasPolicyPlaceholder(kOperatorName),
        isFalse,
        reason: 'kOperatorName',
      );
      expect(
        hasPolicyPlaceholder(kContactEmail),
        isFalse,
        reason: 'kContactEmail',
      );
      expect(
        hasPolicyPlaceholder(kOperatorAddress),
        isFalse,
        reason: 'kOperatorAddress',
      );
      expect(kContactEmail, contains('@'));
    }, skip: skipReason);

    test('the policy files carry no leftover placeholder text', () {
      for (final path in [kPolicyAssetId, kPolicyAssetEn]) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('[FILL IN')),
          reason: path,
        );
      }
    }, skip: skipReason);
  });
}
