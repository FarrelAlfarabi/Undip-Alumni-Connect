import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/stale_cache.dart';
import 'package:undip_alumni_connect/screens/photo_adjust_screen.dart';
import 'package:undip_alumni_connect/util/app_language.dart';

/// The photo adjuster opens a screen after a photo is chosen. Tests of the
/// forms pick a photo and carry on, so it is off unless a test turns it on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PhotoAdjust.enabled = false;
  // Text is checked as written in the code; language tests turn this off.
  AppLanguage.shared.passthrough = true;
  // Nothing a screen kept in memory leaks into the next test.
  setUp(StaleCache.clear);
  await testMain();
}
