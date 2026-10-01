import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';

void main() {
  test('the web lock is off unless a preview build turns it on', () {
    expect(kWebLockTest, isFalse);
  });

  test('only Vercel preview builds pass WEB_LOCK_TEST', () {
    final sh = File('scripts/vercel-build.sh').readAsStringSync();
    expect(sh, contains('WEB_LOCK_TEST=true'));
    expect(sh, contains('"\${VERCEL_ENV:-}" = "preview"'));
    // Never on the build command itself.
    expect(
      RegExp(
        r'^flutter build web[^\n]*WEB_LOCK_TEST',
        multiLine: true,
      ).hasMatch(sh),
      isFalse,
    );
  });
}
