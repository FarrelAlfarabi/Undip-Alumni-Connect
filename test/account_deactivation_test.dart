import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:undip_alumni_connect/config/policy_config.dart';
import 'package:undip_alumni_connect/data/account_repository.dart';
import 'package:undip_alumni_connect/data/deactivated_filter.dart';
import 'package:undip_alumni_connect/data/feedback_repository.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/lock/session.dart';
import 'package:undip_alumni_connect/screens/deactivate_account_screen.dart';
import 'package:undip_alumni_connect/screens/delete_account_screen.dart';
import 'package:undip_alumni_connect/screens/settings_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';

import 'support/fake_lock.dart';

class FakeAccountApi implements AccountApi {
  final calls = <String>[];
  final params = <String, Map<String, dynamic>>{};
  String? failOn;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async {
    calls.add(function);
    params[function] = p;
    if (failOn == function) {
      throw PostgrestException(message: 'boom', code: 'P0001');
    }
    return null;
  }

  @override
  Future<List<String>> removeFiles(String bucket, List<String> paths) async =>
      paths;
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('AccountRepository', () {
    test('deactivateAccount calls account_deactivate and nothing else', () async {
      final api = FakeAccountApi();
      await AccountRepository(api).deactivateAccount('u1');
      expect(api.calls, ['account_deactivate']);
      expect(api.params['account_deactivate'], {'p_profile': 'u1'});
    });

    test('reactivateAccount calls account_reactivate', () async {
      final api = FakeAccountApi();
      await AccountRepository(api).reactivateAccount('u1');
      expect(api.calls, ['account_reactivate']);
      expect(api.params['account_reactivate'], {'p_profile': 'u1'});
    });

    test('a database error becomes an AccountException', () async {
      final api = FakeAccountApi()..failOn = 'account_deactivate';
      expect(
        AccountRepository(api).deactivateAccount('u1'),
        throwsA(isA<AccountException>()),
      );
    });
  });

  group('withoutDeactivatedProfiles', () {
    test('drops rows with deactivated_at set and keeps the rest', () {
      final rows = [
        {'id': 'a', 'deactivated_at': null},
        {'id': 'b', 'deactivated_at': '2026-10-18T10:00:00Z'},
        {'id': 'c'},
      ];
      expect(
        withoutDeactivatedProfiles(rows).map((r) => r['id']),
        ['a', 'c'],
      );
    });
  });

  group('DeactivateAccountScreen', () {
    Future<(FakeAccountApi, MemoryLockStore)> pump(WidgetTester tester) async {
      phone(tester);
      final api = FakeAccountApi();
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      FeedbackSession.profileId = 'p1';
      await tester.pumpWidget(
        MaterialApp(
          home: DeactivateAccountScreen(
            currentUser: ValueNotifier({'id': 'p1', 'name': 'Ahmad Ramadhan'}),
            repository: AccountRepository(api),
            lock: lock,
          ),
        ),
      );
      return (api, store);
    }

    testWidgets('says what is hidden, what stays, and how to come back', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Hidden while deactivated'), findsOneWidget);
      expect(find.text('What stays'), findsOneWidget);
      expect(find.textContaining('Members'), findsWidgets);
      expect(find.textContaining('Nearby Alumni'), findsWidgets);
      expect(find.textContaining('sign in again'), findsOneWidget);
      // Deactivating is not deleting, and the screen says so.
      expect(find.textContaining('not the same as deleting'), findsOneWidget);
    });

    testWidgets('links to Delete my account for people who want data gone', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('deactivate-go-delete')));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    });

    testWidgets('Cancel on the confirm deactivates nothing', (tester) async {
      final (api, _) = await pump(tester);
      await tester.tap(find.byKey(const Key('deactivate-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('confirming deactivates, signs out and shows the notice', (
      tester,
    ) async {
      final (api, _) = await pump(tester);
      await tester.tap(find.byKey(const Key('deactivate-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deactivate-final')));
      await tester.pumpAndSettle();
      expect(api.calls, ['account_deactivate']);
      expect(FeedbackSession.profileId, isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text(kAccountDeactivatedNotice), findsOneWidget);
    });

    testWidgets('a failed call keeps the person signed in and shows an error', (
      tester,
    ) async {
      phone(tester);
      final api = FakeAccountApi()..failOn = 'account_deactivate';
      FeedbackSession.profileId = 'p1';
      await tester.pumpWidget(
        MaterialApp(
          home: DeactivateAccountScreen(
            currentUser: ValueNotifier({'id': 'p1', 'name': 'Ahmad'}),
            repository: AccountRepository(api),
            lock: await makeRememberedLock(store: MemoryLockStore()),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('deactivate-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deactivate-final')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('deactivate-error')), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(FeedbackSession.profileId, 'p1');
    });
  });

  group('Settings', () {
    testWidgets('offers Deactivate next to Delete, never instead of it', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            currentUser: ValueNotifier({'id': 'p1', 'name': 'Ahmad'}),
            showPin: false,
          ),
        ),
      );
      final deactivate = find.byKey(const Key('profile-deactivate'));
      final delete = find.byKey(const Key('profile-delete'));
      expect(deactivate, findsOneWidget);
      expect(delete, findsOneWidget);
      expect(
        tester.getTopLeft(deactivate).dy < tester.getTopLeft(delete).dy,
        isTrue,
      );
    });
  });

  group('enterApp', () {
    testWidgets('signing back in reactivates a deactivated account', (
      tester,
    ) async {
      phone(tester);
      final api = FakeAccountApi();
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      enterApp(
        ctx,
        {
          'id': 'p1',
          'name': 'Ahmad',
          'policy_version': kPolicyVersion,
          'deactivated_at': '2026-10-18T10:00:00Z',
        },
        lock: await makeRememberedLock(store: MemoryLockStore()),
        homeBuilder: (p) => Scaffold(body: Text('APP ${p['deactivated_at']}')),
        accountRepository: AccountRepository(api),
      );
      await tester.pumpAndSettle();
      expect(api.calls, ['account_reactivate']);
      expect(api.params['account_reactivate'], {'p_profile': 'p1'});
      expect(find.text('APP null'), findsOneWidget);
    });

    testWidgets('an active account triggers no reactivation call', (
      tester,
    ) async {
      phone(tester);
      final api = FakeAccountApi();
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      enterApp(
        ctx,
        {'id': 'p1', 'name': 'Ahmad', 'policy_version': kPolicyVersion},
        lock: await makeRememberedLock(store: MemoryLockStore()),
        homeBuilder: (p) => const Scaffold(body: Text('APP')),
        accountRepository: AccountRepository(api),
      );
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
    });
  });
}
