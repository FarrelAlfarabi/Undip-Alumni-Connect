import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/policy_config.dart';
import 'package:undip_alumni_connect/data/account_repository.dart';
import 'package:undip_alumni_connect/data/block_list.dart';
import 'package:undip_alumni_connect/data/feedback_repository.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/lock/session.dart';
import 'package:undip_alumni_connect/policy/consent_screen.dart';
import 'package:undip_alumni_connect/policy/policy_screen.dart';
import 'package:undip_alumni_connect/policy/policy_text.dart';
import 'package:undip_alumni_connect/screens/delete_account_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_lock.dart';

/// Reads the policy files straight from disk, so widget tests do not wait on
/// the real asset loader.
class DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

Widget withPolicyBundle(Widget app) =>
    DefaultAssetBundle(bundle: DiskBundle(), child: app);

class FakeAccountApi implements AccountApi {
  final calls = <String>[];
  final params = <String, Map<String, dynamic>>{};
  Object? failOn;
  String failMessage = 'boom';
  Object? failRemove;
  Set<String>? removeOnly;
  List<Map<String, dynamic>> files = const [];

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async {
    calls.add(function);
    params[function] = p;
    if (failOn == function) {
      throw PostgrestException(message: failMessage, code: 'P0001');
    }
    if (function == 'account_files') return files;
    if (function == 'account_delete') {
      return {
        'deleted': true,
        'removed': {'businesses': 1, 'products': 2},
        'files': files,
      };
    }
    return null;
  }

  @override
  Future<List<String>> removeFiles(String bucket, List<String> paths) async {
    calls.add('remove:$bucket');
    if (failRemove != null) throw failRemove!;
    return paths
        .where((p) => removeOnly == null || removeOnly!.contains(p))
        .toList();
  }
}

Widget appHome(Map<String, dynamic> p) =>
    Scaffold(body: Text('APP for ${p['name']}'));

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('policy text', () {
    test('version, dates and the two placeholders live in one config file', () {
      expect(kPolicyVersion, isNotEmpty);
      expect(kPolicyUpdatedId, isNotEmpty);
      expect(kPolicyUpdatedEn, isNotEmpty);
      expect(kOperatorName, isNotEmpty);
      expect(kContactEmail, isNotEmpty);
    });

    for (final lang in PolicyLanguage.values) {
      testWidgets(
        '${lang.name}: loads, tokens are filled, key facts are present',
        (tester) async {
          final text = await tester.runAsync(() => loadPolicyText(lang));
          expect(text, isNotNull);
          expect(text!.contains('{{'), isFalse);
          expect(text, contains(kPolicyVersion));
          expect(text, contains(kOperatorName));
          expect(text, contains(kContactEmail));
          // Built from what the app really stores and does.
          for (final fact in [
            'NIM',
            'CV',
            'GPS',
            'PIN',
            'Google Fonts',
            'Delete my account',
            'Send feedback',
            'NIM',
            'Ikafe',
          ]) {
            expect(text, contains(fact), reason: '$fact in ${lang.name}');
          }
        },
      );
    }

    testWidgets('the two files carry the same sections (10 each)', (
      tester,
    ) async {
      final id = (await tester.runAsync(
        () => loadPolicyText(PolicyLanguage.id),
      ))!;
      final en = (await tester.runAsync(
        () => loadPolicyText(PolicyLanguage.en),
      ))!;
      expect(RegExp(r'^## ', multiLine: true).allMatches(id).length, 10);
      expect(RegExp(r'^## ', multiLine: true).allMatches(en).length, 10);
    });

    testWidgets('community rules are in both languages', (tester) async {
      final id = (await tester.runAsync(
        () => loadPolicyText(PolicyLanguage.id),
      ))!;
      final en = (await tester.runAsync(
        () => loadPolicyText(PolicyLanguage.en),
      ))!;
      expect(en, contains('No spam'));
      expect(en, contains('block people'));
      expect(id, contains('Aturan komunitas'));
    });

    testWidgets('screen: draft banner, Indonesian first, switch to English', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        withPolicyBundle(const MaterialApp(home: PolicyScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('policy-draft-banner')), findsOneWidget);
      expect(
        find.textContaining('Draft for the beta. The text may change.'),
        findsOneWidget,
      );
      expect(
        find.text('Kebijakan privasi dan aturan komunitas'),
        findsOneWidget,
      );
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy policy and community rules'), findsWidgets);
      expect(find.text('Kebijakan privasi dan aturan komunitas'), findsNothing);
    });
  });

  group('consent', () {
    test(
      'needed only when the accepted version differs from the current one',
      () {
        expect(needsConsent({'policy_version': null}), isTrue);
        expect(needsConsent({}), isTrue);
        expect(needsConsent({'policy_version': 'old-version'}), isTrue);
        expect(needsConsent({'policy_version': kPolicyVersion}), isFalse);
      },
    );

    Future<(FakeAccountApi, MemoryLockStore)> launch(
      WidgetTester tester,
      Map<String, dynamic> profile,
    ) async {
      phone(tester);
      final api = FakeAccountApi();
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await tester.pumpWidget(
        withPolicyBundle(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  onPressed: () => enterApp(
                    ctx,
                    profile,
                    lock: lock,
                    homeBuilder: appHome,
                    accountRepository: AccountRepository(api),
                  ),
                  child: const Text('ENTER'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ENTER'));
      await tester.pumpAndSettle();
      return (api, store);
    }

    testWidgets(
      'not accepted: the consent screen comes first, the app stays out of reach',
      (tester) async {
        await launch(tester, testProfile(policyVersion: null));
        expect(find.byKey(const Key('consent-screen')), findsOneWidget);
        expect(find.textContaining('APP for'), findsNothing);
        // Continue is off until the box is ticked.
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('consent-continue')))
              .onPressed,
          isNull,
        );
        expect(find.byKey(const Key('policy-draft-banner')), findsOneWidget);
      },
    );

    testWidgets(
      'tick the box, Continue saves the current version and enters the app',
      (tester) async {
        final (api, _) = await launch(tester, testProfile(policyVersion: null));
        await tester.tap(find.byKey(const Key('consent-checkbox')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('consent-continue')));
        await tester.pumpAndSettle();
        expect(api.params['account_accept_policy'], {
          'p_profile': 'p1',
          'p_version': kPolicyVersion,
        });
        expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      },
    );

    testWidgets('already accepted: no consent screen at all', (tester) async {
      await launch(tester, testProfile());
      expect(find.byKey(const Key('consent-screen')), findsNothing);
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
    });

    testWidgets('an older accepted version asks again (the constant changed)', (
      tester,
    ) async {
      await launch(tester, testProfile(policyVersion: '2026-01-01-old'));
      expect(find.byKey(const Key('consent-screen')), findsOneWidget);
    });

    testWidgets(
      'a failed save keeps them on the screen with a message and Send feedback',
      (tester) async {
        final (api, _) = await launch(tester, testProfile(policyVersion: null));
        api.failOn = 'account_accept_policy';
        await tester.tap(find.byKey(const Key('consent-checkbox')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('consent-continue')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('consent-error')), findsOneWidget);
        expect(find.byKey(const Key('send-feedback')), findsOneWidget);
        expect(find.textContaining('APP for'), findsNothing);
      },
    );

    testWidgets('they can go back and sign out', (tester) async {
      await launch(tester, testProfile(policyVersion: null));
      await tester.tap(find.byKey(const Key('consent-back')));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byKey(const Key('consent-screen')), findsNothing);
    });

    testWidgets('first run order: verify, consent, PIN offer, app', (
      tester,
    ) async {
      phone(tester);
      final api = FakeAccountApi();
      final lock = makeLock(store: MemoryLockStore());
      await tester.pumpWidget(
        withPolicyBundle(
          MaterialApp(
            home: VerificationScreen(
              lock: lock,
              verifyEmail: (email) async => testProfile(policyVersion: null),
              homeBuilder: appHome,
              accountRepository: AccountRepository(api),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), testEmail);
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('consent-screen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('consent-checkbox')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('consent-continue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pin-setup')), findsOneWidget);
    });
  });

  group('AccountRepository', () {
    test('deletes: lists the files, tries to remove them, then calls the database function', () async {
      final api = FakeAccountApi()
        ..files = [
          {'bucket': 'marketplace', 'path': 'u1/a.png'},
          {'bucket': 'cvs', 'path': 'u1/cv.pdf'},
        ];
      final result = await AccountRepository(api).deleteAccount('u1');
      expect(api.calls, [
        'account_files',
        'account_delete',
        'remove:marketplace',
        'remove:cvs',
      ]);
      expect(api.params['account_delete'], {'p_profile': 'u1'});
      expect(result.removed, {'businesses': 1, 'products': 2});
      expect(result.failedPaths, isEmpty);
    });

    test('a refused file removal does not stop the deletion, and the paths are in the result', () async {
      final api = FakeAccountApi()
        ..files = [
          {'bucket': 'marketplace', 'path': 'u1/a.png'},
          {'bucket': 'cvs', 'path': 'u1/cv.pdf'},
        ]
        ..failRemove = Exception('not allowed');
      final result = await AccountRepository(api).deleteAccount('u1');
      expect(api.calls.contains('account_delete'), isTrue);
      expect(result.failedPaths, ['marketplace/u1/a.png', 'cvs/u1/cv.pdf']);
    });

    test(
      'files the storage did not report as removed count as failed',
      () async {
        final api = FakeAccountApi()
          ..files = [
            {'bucket': 'marketplace', 'path': 'a.png'},
            {'bucket': 'marketplace', 'path': 'b.png'},
          ]
          ..removeOnly = {'a.png'};
        final result = await AccountRepository(api).deleteAccount('u1');
        expect(result.failedPaths, ['marketplace/b.png']);
      },
    );

    test('if the database call fails, no file has been removed', () async {
      final api = FakeAccountApi()
        ..files = [
          {'bucket': 'cvs', 'path': 'u1/cv.pdf'},
        ]
        ..failOn = 'account_delete';
      await expectLater(
        AccountRepository(api).deleteAccount('u1'),
        throwsA(isA<AccountException>()),
      );
      expect(api.calls.any((c) => c.startsWith('remove:')), isFalse);
    });

    test(
      'not_found on a retry means it was already deleted: success',
      () async {
        final api = FakeAccountApi()
          ..failOn = 'account_delete'
          ..failMessage = 'not_found';
        final result = await AccountRepository(api).deleteAccount('u1');
        expect(result.removed, isEmpty);
        expect(result.failedPaths, isEmpty);
      },
    );

    test('other database errors still surface', () async {
      final api = FakeAccountApi()
        ..failOn = 'account_delete'
        ..failMessage = 'permission denied';
      await expectLater(
        AccountRepository(api).deleteAccount('u1'),
        throwsA(isA<AccountException>()),
      );
    });

    test('a database failure surfaces as an AccountException', () async {
      final api = FakeAccountApi()..failOn = 'account_delete';
      expect(
        AccountRepository(api).deleteAccount('u1'),
        throwsA(isA<AccountException>()),
      );
    });
  });

  group('Delete my account', () {
    test('the confirmation word is HAPUS or the first name, any case', () {
      expect(deleteConfirmationMatches('HAPUS', 'Ahmad Ramadhan'), isTrue);
      expect(deleteConfirmationMatches(' hapus ', 'Ahmad Ramadhan'), isTrue);
      expect(deleteConfirmationMatches('ahmad', 'Ahmad Ramadhan'), isTrue);
      expect(deleteConfirmationMatches('Ramadhan', 'Ahmad Ramadhan'), isFalse);
      expect(deleteConfirmationMatches('', 'Ahmad'), isFalse);
      expect(deleteConfirmationMatches('hapuss', 'Ahmad'), isFalse);
    });

    Future<(FakeAccountApi, MemoryLockStore)> pumpDelete(
      WidgetTester tester,
    ) async {
      phone(tester);
      tester.view.physicalSize = const Size(420, 2200);
      final api = FakeAccountApi();
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      FeedbackSession.profileId = 'p1';
      BlockList.shared = BlockList.preloaded({'u9'});
      await tester.pumpWidget(
        MaterialApp(
          home: DeleteAccountScreen(
            currentUser: ValueNotifier({'id': 'p1', 'name': 'Ahmad Ramadhan'}),
            repository: AccountRepository(api),
            lock: lock,
          ),
        ),
      );
      return (api, store);
    }

    testWidgets('explains what is removed and what is kept, in plain words', (
      tester,
    ) async {
      await pumpDelete(tester);
      expect(find.text('What is removed'), findsOneWidget);
      expect(find.text('What is kept'), findsOneWidget);
      expect(
        find.textContaining('Your businesses and products'),
        findsOneWidget,
      );
      expect(find.textContaining('Reports you filed'), findsOneWidget);
      expect(find.textContaining('cannot verify again'), findsOneWidget);
    });

    testWidgets('the button stays off until HAPUS or the first name is typed', (
      tester,
    ) async {
      await pumpDelete(tester);
      bool enabled() =>
          tester
              .widget<FilledButton>(find.byKey(const Key('delete-button')))
              .onPressed !=
          null;
      expect(enabled(), isFalse);
      await tester.enterText(find.byKey(const Key('delete-field')), 'hapus');
      await tester.pump();
      expect(enabled(), isTrue);
      await tester.enterText(find.byKey(const Key('delete-field')), 'Ahmad');
      await tester.pump();
      expect(enabled(), isTrue);
      await tester.enterText(find.byKey(const Key('delete-field')), 'no');
      await tester.pump();
      expect(enabled(), isFalse);
    });

    testWidgets('a final confirm, and Cancel deletes nothing', (tester) async {
      final (api, _) = await pumpDelete(tester);
      await tester.enterText(find.byKey(const Key('delete-field')), 'HAPUS');
      await tester.pump();
      await tester.tap(find.byKey(const Key('delete-button')));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account for good?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
    });

    testWidgets('confirmed: deletes, wipes the device, lands on Welcome', (
      tester,
    ) async {
      final (api, store) = await pumpDelete(tester);
      expect(store.data, isNotEmpty);
      await tester.enterText(find.byKey(const Key('delete-field')), 'HAPUS');
      await tester.pump();
      await tester.tap(find.byKey(const Key('delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-final')));
      await tester.pumpAndSettle();
      expect(
        api.calls,
        containsAllInOrder(['account_files', 'account_delete']),
      );
      expect(api.params['account_delete'], {'p_profile': 'p1'});
      // Everything on the device is gone: PIN, remembered person, block list, feedback session.
      expect(store.data, isEmpty);
      expect(FeedbackSession.profileId, isNull);
      expect(BlockList.shared.blocked.value, isEmpty);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text(kAccountDeletedNotice), findsOneWidget);
    });

    testWidgets(
      'a failed deletion keeps the account, the PIN and the person on the screen, with Send feedback',
      (tester) async {
        final (api, store) = await pumpDelete(tester);
        api.failOn = 'account_delete';
        await tester.enterText(find.byKey(const Key('delete-field')), 'HAPUS');
        await tester.pump();
        await tester.tap(find.byKey(const Key('delete-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('delete-final')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('delete-error')), findsOneWidget);
        expect(find.byKey(const Key('send-feedback')), findsOneWidget);
        expect(store.data, isNotEmpty);
        expect(find.byType(WelcomeScreen), findsNothing);
      },
    );
  });

  group('Profile entries', () {
    testWidgets('policy and delete are on my own profile, not on others', (
      tester,
    ) async {
      phone(tester);
      tester.view.physicalSize = const Size(420, 2200);
      Widget screen(bool own) => MaterialApp(
        key: UniqueKey(),
        home: ProfileDetailScreen(
          profile: {'id': own ? 'me' : 'u2', 'name': 'X'},
          currentUser: ValueNotifier({'id': 'me'}),
          showEditButton: own,
          chat: false,
          adminCheck: (_) async => false,
        ),
      );
      await tester.pumpWidget(screen(true));
      expect(find.byKey(const Key('profile-settings')), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-policy')), findsOneWidget);
      expect(find.byKey(const Key('profile-delete')), findsOneWidget);
      await tester.pumpWidget(screen(false));
      expect(find.byKey(const Key('profile-settings')), findsNothing);
      expect(find.byKey(const Key('profile-policy')), findsNothing);
      expect(find.byKey(const Key('profile-delete')), findsNothing);
    });
  });
}
