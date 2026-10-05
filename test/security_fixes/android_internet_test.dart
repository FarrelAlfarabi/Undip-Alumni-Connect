import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Release Android builds only get the permissions in the MAIN manifest. The
/// debug and profile manifests add INTERNET for development, so a debug APK
/// works while a release build cannot reach Supabase at all. The CI only
/// builds debug, which hides this.
void main() {
  test('main AndroidManifest declares the INTERNET permission', () {
    final text = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      text,
      contains('<uses-permission android:name="android.permission.INTERNET"/>'),
    );
  });
}
