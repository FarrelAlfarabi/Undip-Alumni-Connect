import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';
import 'support/fake_marketplace_api.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('repository', () {
    test(
      'isAdmin asks is_app_admin with the profile id, true only for true',
      () async {
        final api = FakeAdminApi()..results['is_app_admin'] = true;
        expect(await AdminRepository(api).isAdmin('me'), isTrue);
        expect(api.params['is_app_admin'], {'p_profile': 'me'});
        api.results['is_app_admin'] = false;
        expect(await AdminRepository(api).isAdmin('me'), isFalse);
      },
    );

    test('no admin call ever carries a passphrase', () async {
      final api = FakeAdminApi()
        ..results['admin_business_decide'] = businessMap();
      final repo = AdminRepository(api);
      await repo.businesses('a');
      await repo.approve('a', 'b', BusinessBand.small);
      await repo.reject('a', 'b', 'x');
      await repo.suspend('a', 'b');
      await repo.restore('a', 'b');
      expect(api.allParams, isNotEmpty);
      for (final p in api.allParams) {
        expect(p.containsKey('p_key'), isFalse);
        expect(p['p_admin'], 'a');
      }
    });

    test('approve sends the band, reject sends the trimmed reason, nothing touches unlimited_until', () async {
      final api = FakeAdminApi()
        ..results['admin_business_decide'] = businessMap();
      final repo = AdminRepository(api);
      await repo.approve('a', 'b1', BusinessBand.medium);
      expect(api.params['admin_business_decide'], {
        'p_admin': 'a',
        'p_business': 'b1',
        'p_action': 'approve',
        'p_band': 'medium',
        'p_reason': null,
      });
      await repo.reject('a', 'b1', '  Link rusak ');
      expect(api.params['admin_business_decide']!['p_reason'], 'Link rusak');
      for (final p in api.allParams) {
        expect(p.keys.any((k) => k.contains('unlimited')), isFalse);
      }
    });

    test('database codes become plain messages', () async {
      final cases = {
        'not_admin': AdminErrorCode.notAdmin,
        'invalid_band': AdminErrorCode.invalidBand,
        'reason_required': AdminErrorCode.reasonRequired,
        'invalid_state': AdminErrorCode.invalidState,
      };
      for (final e in cases.entries) {
        final api = FakeAdminApi()..throwOnCall = pgError(e.key);
        try {
          await AdminRepository(api).businesses('a');
          fail('should throw');
        } on AdminException catch (ex) {
          expect(ex.code, e.value);
          expect(adminErrorMessage(ex), isNot(contains('_')));
        }
      }
    });
  });

  group('Admin entry in Profile', () {
    Future<List<String>> pump(
      WidgetTester tester,
      Future<bool> Function(String) check,
    ) async {
      phone(tester);
      final asked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileDetailScreen(
            profile: {'id': 'me', 'name': 'Gilang', 'email': 'g@example.com'},
            currentUser: ValueNotifier({'id': 'me', 'name': 'Gilang'}),
            adminCheck: (id) {
              asked.add(id);
              return check(id);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return asked;
    }

    testWidgets('shown only when the database says admin, asked once', (
      tester,
    ) async {
      final asked = await pump(tester, (_) async => true);
      expect(find.byKey(const Key('profile-admin')), findsOneWidget);
      expect(asked, ['me']);
    });

    testWidgets('hidden for everyone else', (tester) async {
      await pump(tester, (_) async => false);
      expect(find.byKey(const Key('profile-admin')), findsNothing);
    });

    testWidgets('a failed check hides it (no crash)', (tester) async {
      await pump(tester, (_) async => throw Exception('network'));
      expect(find.byKey(const Key('profile-admin')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('someone else profile never asks', (tester) async {
      phone(tester);
      var asked = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileDetailScreen(
            profile: {'id': 'u2', 'name': 'Siti'},
            currentUser: ValueNotifier({'id': 'me'}),
            showEditButton: false,
            chat: false,
            adminCheck: (_) async {
              asked++;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(asked, 0);
      expect(find.byKey(const Key('profile-admin')), findsNothing);
    });
  });

  group('Admin screen', () {
    testWidgets('lists Businesses and Marketplace review, no passphrase', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminScreen(
            adminId: 'me',
            adminRepository: AdminRepository(FakeAdminApi()),
            marketplaceRepository: MarketplaceRepository(FakeApi()),
          ),
        ),
      );
      expect(find.text('Businesses'), findsOneWidget);
      expect(find.text('Marketplace review'), findsOneWidget);
      expect(find.textContaining('assphrase'), findsNothing);
    });
  });

  group('Businesses admin', () {
    Future<FakeAdminApi> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows, {
      double width = 420,
    }) async {
      phone(tester);
      tester.view.physicalSize = Size(width, 1600);
      final api = FakeAdminApi()
        ..results['admin_businesses_list'] = rows
        ..results['admin_business_decide'] = businessMap(
          status: 'approved',
          approvedBand: 'small',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: AdminBusinessesScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('loads pending first and shows what the admin needs', (
      tester,
    ) async {
      final api = await pump(tester, [businessMap(ownerName: 'Ahmad')]);
      expect(api.params['admin_businesses_list'], {
        'p_admin': 'me',
        'p_status': 'pending',
      });
      expect(find.text('Kopi Ahmad'), findsOneWidget);
      expect(find.textContaining('by Ahmad'), findsOneWidget);
      expect(
        find.textContaining('Band chosen by owner: Small'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('approve-b1')), findsOneWidget);
      expect(find.byKey(const Key('reject-b1')), findsOneWidget);
    });

    testWidgets('approve: the admin picks the band from the four', (
      tester,
    ) async {
      final api = await pump(tester, [businessMap()]);
      await tester.tap(find.byKey(const Key('approve-b1')));
      await tester.pumpAndSettle();
      for (final b in BusinessBand.values) {
        expect(find.byKey(Key('approve-band-${b.name}')), findsOneWidget);
      }
      // The band the owner asked for is preselected, the admin can change it.
      await tester.tap(find.byKey(const Key('approve-band-micro')));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Approve'),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.params['admin_business_decide'], {
        'p_admin': 'me',
        'p_business': 'b1',
        'p_action': 'approve',
        'p_band': 'micro',
        'p_reason': null,
      });
    });

    testWidgets('reject needs a reason', (tester) async {
      final api = await pump(tester, [businessMap()]);
      await tester.tap(find.byKey(const Key('reject-b1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(find.text('A reason is required'), findsOneWidget);
      expect(api.calls.contains('admin_business_decide'), isFalse);
      await tester.enterText(find.byType(TextField), 'Link rusak');
      await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(api.params['admin_business_decide']!['p_action'], 'reject');
      expect(api.params['admin_business_decide']!['p_reason'], 'Link rusak');
    });

    testWidgets('approved can be suspended', (tester) async {
      final api = await pump(tester, [
        businessMap(id: 'a', status: 'approved', approvedBand: 'micro'),
      ]);
      expect(find.byKey(const Key('suspend-a')), findsOneWidget);
      expect(find.byKey(const Key('approve-a')), findsNothing);
      await tester.tap(find.byKey(const Key('suspend-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Suspend'));
      await tester.pumpAndSettle();
      expect(api.params['admin_business_decide']!['p_action'], 'suspend');
    });

    testWidgets('suspended can be restored', (tester) async {
      final api = await pump(tester, [
        businessMap(id: 's', status: 'suspended', approvedBand: 'micro'),
      ]);
      await tester.tap(find.byKey(const Key('restore-s')));
      await tester.pumpAndSettle();
      expect(api.params['admin_business_decide']!['p_action'], 'restore');
    });

    testWidgets('a refusal from the database is shown in plain words', (
      tester,
    ) async {
      final api = await pump(tester, [businessMap()]);
      api.throwOnCall = null;
      await tester.tap(find.byKey(const Key('reject-b1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'x');
      api.throwOnCall = pgError('not_admin');
      await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(find.text('You are not an admin.'), findsOneWidget);
    });

    testWidgets('status chips reload with that status', (tester) async {
      final api = await pump(tester, [], width: 900);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Suspended'));
      await tester.pumpAndSettle();
      expect(api.params['admin_businesses_list']!['p_status'], 'suspended');
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(api.params['admin_businesses_list']!['p_status'], isNull);
    });
  });
}
