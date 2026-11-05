import 'dart:async';

import 'package:undip_alumni_connect/screens/photo_adjust_screen.dart';

/// The photo adjuster opens a screen after a photo is chosen. Tests of the
/// forms pick a photo and carry on, so it is off unless a test turns it on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PhotoAdjust.enabled = false;
  await testMain();
}
