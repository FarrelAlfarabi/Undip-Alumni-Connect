import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:undip_alumni_connect/data/account_repository.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/screens/feature_intro_screen.dart';
import 'package:undip_alumni_connect/screens/settings_screen.dart';

import 'support/fake_lock.dart';

class FakeAccountApi implements AccountApi {
  final calls = <String>[];
  final params = <String, Map<String, dynamic>>{};
  String? failOn;
  bool seenOnServer = false;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async {
    calls.add(function);
    params[function] = p;
    if (failOn == function) {
      throw PostgrestException(message: 'boom', code: 'P0001');
    }
    if (function == 'account_intro_seen') return seenOnServer;
    return null;
  }

  @override
  Future<List<String>> removeFiles(String bucket, List<String> paths) async =>
      const [];
}

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

  group('IntroGate', () {
    late FakeAccountApi api;
    late AccountRepository repo;

    setUp(() {
      api = FakeAccountApi();
      repo = AccountRepository(api);
    });

    Future<void> open(
      WidgetTester tester,
      LockService lock, {
      Map<String, dynamic>? profile,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: IntroGate(
            profile: profile ?? testProfile(),
            lock: lock,
            repository: repo,
            child: const Text('HOME'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('first login: shows the intro and saves it to Supabase', (
      tester,
    ) async {
      final lock = await makeRememberedLock();
      await open(tester, lock);
      expect(find.byKey(const Key('intro-skip')), findsOneWidget);
      expect(api.calls, ['account_intro_seen']);

      await tester.tap(find.byKey(const Key('intro-skip')));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(api.calls, ['account_intro_seen', 'account_mark_intro_seen']);
      expect(api.params['account_mark_intro_seen'], {'p_profile': 'p1'});
      expect(await lock.introSeen('p1'), isTrue);
    });

    testWidgets('already seen on the server: no intro, even on a new device', (
      tester,
    ) async {
      final lock = await makeRememberedLock();
      api.seenOnServer = true;
      await open(tester, lock);
      expect(find.byKey(const Key('intro-skip')), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
      expect(api.calls, ['account_intro_seen']);
    });

    testWidgets(
      'seen on this device before: no intro, and Supabase learns it',
      (tester) async {
        final lock = await makeRememberedLock();
        await lock.markIntroSeen('p1');
        await open(tester, lock);
        expect(find.byKey(const Key('intro-skip')), findsNothing);
        expect(find.text('HOME'), findsOneWidget);
        expect(api.calls, ['account_mark_intro_seen']);
      },
    );

    testWidgets('a failed save does not block the app', (tester) async {
      final lock = await makeRememberedLock();
      api.failOn = 'account_mark_intro_seen';
      await open(tester, lock);
      await tester.tap(find.byKey(const Key('intro-skip')));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byKey(const Key('intro-skip')), findsNothing);
    });

    testWidgets('migration not applied yet: the local flag decides', (
      tester,
    ) async {
      final lock = await makeRememberedLock();
      api.failOn = 'account_intro_seen';
      await open(tester, lock);
      expect(find.byKey(const Key('intro-skip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('intro-skip')));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);

      // Same device again: the local flag now says seen.
      await open(tester, lock);
      expect(find.byKey(const Key('intro-skip')), findsNothing);
    });
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
