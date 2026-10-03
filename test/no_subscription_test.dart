import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Stage 3 guard: the subscription is gone from the app. No Subscribe screen,
/// no price copy, no "subscribers only" gate.
void main() {
  final files = [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f,
  ];

  test('the Subscribe screen and the marketplace gate are deleted', () {
    expect(File('lib/screens/subscribe_screen.dart').existsSync(), isFalse);
    expect(File('lib/screens/marketplace_gate.dart').existsSync(), isFalse);
  });

  test('no subscription wording or code in lib/', () {
    final banned = RegExp(
      r'SubscribeScreen|ensureSubscriber|isSubscribed|demo_subscribe|'
      r'Rp\s*99|99\.000|subscribers only|Subscribe to|subscriber_required|'
      r'subscription_status',
      caseSensitive: false,
    );
    final hits = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
