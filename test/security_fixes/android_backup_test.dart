import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SA-22: Android auto-backup must not copy the app's data (the PIN hash and
/// the remembered-person record live in the secure-storage file). The
/// Keystore key is not backed up, so a restored copy is useless anyway; better
/// to never copy it.
void main() {
  test('AndroidManifest turns off auto-backup', () {
    final text = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(text, contains('android:allowBackup="false"'));
  });
}
