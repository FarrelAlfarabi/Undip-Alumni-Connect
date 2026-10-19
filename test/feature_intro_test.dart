import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/screens/feature_intro_screen.dart';
import 'package:undip_alumni_connect/screens/settings_screen.dart';

import 'support/fake_lock.dart';

void main() {
  testWidgets('intro explains Marketplace and Business, then finishes', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(home: FeatureIntroScreen(onDone: (_) async => done++)),
    );
    expect(find.textContaining('Marketplace'), findsWidgets);
    expect(find.byKey(const Key('intro-skip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('intro-next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Business'), findsWidgets);

    await tester.tap(find.byKey(const Key('intro-next')));
    await tester.pumpAndSettle();
    expect(done, 1);
  });

  testWidgets('Skip finishes right away', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(home: FeatureIntroScreen(onDone: (_) async => done++)),
    );
    await tester.tap(find.byKey(const Key('intro-skip')));
    await tester.pumpAndSettle();
    expect(done, 1);
  });

  test('intro seen flag is per person and kept on the device', () async {
    final store = MemoryLockStore();
    final lock = makeLock(store: store);
    expect(await lock.introSeen('p1'), isFalse);
    await lock.markIntroSeen('p1');
    expect(await lock.introSeen('p1'), isTrue);
    expect(await lock.introSeen('p2'), isFalse);
  });

  testWidgets('IntroGate shows the intro once, then goes straight home', (
    tester,
  ) async {
    final lock = await makeRememberedLock();
    Future<void> open() async {
      await tester.pumpWidget(
        MaterialApp(
          home: IntroGate(
            profileId: 'p1',
            lock: lock,
            child: const Text('HOME'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.byKey(const Key('intro-skip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('intro-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intro-skip')), findsNothing);
    expect(find.text('HOME'), findsOneWidget);

    await open();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(const Key('intro-skip')), findsNothing);
  });

  testWidgets('Settings can reopen the intro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          currentUser: ValueNotifier(testProfile()),
          showPin: false,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-intro')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intro-next')), findsOneWidget);

    // Reopened from Settings, finishing just goes back.
    await tester.tap(find.byKey(const Key('intro-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-intro')), findsOneWidget);
  });
}
