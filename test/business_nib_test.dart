import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/business_directory_screen.dart';
import 'package:undip_alumni_connect/screens/business_form_screen.dart';
import 'package:undip_alumni_connect/screens/my_businesses_screen.dart';
import 'package:undip_alumni_connect/widgets/verified_badge.dart';

import 'support/choose_category.dart';
import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('NIB format', () {
    test('13 digits only; spaces and dashes are ignored', () {
      expect(cleanNib('1234567890123'), '1234567890123');
      expect(cleanNib(' 1234 5678-9012 3 '), '1234567890123');
      expect(cleanNib(''), isNull);
      expect(cleanNib('   '), isNull);
      expect(isValidNib('1234567890123'), isTrue);
      expect(isValidNib('123456789012'), isFalse);
      expect(isValidNib('12345678901234'), isFalse);
      expect(isValidNib('12345678901ab'), isFalse);
    });
  });

  group('repository', () {
    test('setNib sends the owner, business and the clean number', () async {
      final api = FakeBusinessApi()
        ..results['business_set_nib'] = businessMap(nib: '1234567890123');
      final b = await BusinessRepository(api)
          .setNib('me', 'b1', '1234 5678 90123');
      expect(api.params['business_set_nib'], {
        'p_owner': 'me',
        'p_business': 'b1',
        'p_nib': '1234567890123',
      });
      expect(b.nib, '1234567890123');
      // The app can never ask to be verified.
      expect(
        api.params['business_set_nib']!.keys.any((k) => k.contains('verif')),
        isFalse,
      );
    });

    test('setNib with empty text clears the number', () async {
      final api = FakeBusinessApi()
        ..results['business_set_nib'] = businessMap();
      await BusinessRepository(api).setNib('me', 'b1', '  ');
      expect(api.params['business_set_nib']!['p_nib'], isNull);
    });

    test('register and update never carry verification', () async {
      final api = FakeBusinessApi()
        ..results['business_register'] = businessMap();
      await BusinessRepository(api).register(
        'me',
        const BusinessInput(
          name: 'N1',
          description: 'd',
          category: 'Other',
          socialLink: 'https://x.example',
          band: BusinessBand.micro,
        ),
      );
      expect(
        api.params['business_register']!.keys.any((k) => k.contains('nib')),
        isFalse,
      );
    });

    test('the directory marks businesses the admin verified', () async {
      final api = FakeBusinessApi()
        ..results['business_directory'] = [
          {...businessMap(id: 'b1')}..remove('status'),
          {...businessMap(id: 'b2', social: 'https://instagram.com/x2')}
            ..remove('status'),
        ]
        ..results['business_nib_verified_ids'] = [
          {'business_id': 'b2'},
        ];
      final list = await BusinessRepository(api).directory('me');
      expect(list.firstWhere((b) => b.id == 'b1').nibVerified, isFalse);
      expect(list.firstWhere((b) => b.id == 'b2').nibVerified, isTrue);
      expect(api.params['business_nib_verified_ids'], {'p_viewer': 'me'});
    });

    test('a failing badge call still gives the list', () async {
      final api = FakeBusinessApi()
        ..results['business_directory'] = [
          {...businessMap()}..remove('status'),
        ];
      final repo = BusinessRepository(api);
      final list = await repo.directory('me');
      expect(list.single.nibVerified, isFalse);
    });

    test('my own row keeps nib and the verified flag', () {
      final b = Business.fromMap(
        businessMap(nib: '1234567890123', nibVerified: true),
      );
      expect(b.nib, '1234567890123');
      expect(b.nibVerified, isTrue);
    });
  });

  group('form', () {
    Future<FakeBusinessApi> pumpForm(
      WidgetTester tester, {
      Business? existing,
    }) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_register'] = businessMap()
        ..results['business_update'] = businessMap()
        ..results['business_set_nib'] = businessMap(nib: '1234567890123');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => BusinessFormScreen(
                      ownerId: 'me',
                      repository: BusinessRepository(api),
                      existing: existing,
                    ),
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> fillBasics(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name *'),
        'Kopi Ahmad',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Short description *'),
        'Kopi',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Instagram *'),
        '@kopi_ahmad',
      );
      await chooseCategory(tester, 'Food & Drink');
      await tester.tap(find.text(BusinessBand.small.label));
      await tester.pumpAndSettle();
    }

    testWidgets('NIB is optional: empty field saves and sets nothing', (
      tester,
    ) async {
      final api = await pumpForm(tester);
      expect(find.byKey(const Key('nib-field')), findsOneWidget);
      await fillBasics(tester);
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('business_register'));
      expect(api.calls, isNot(contains('business_set_nib')));
    });

    testWidgets('a wrong NIB is refused before sending', (tester) async {
      final api = await pumpForm(tester);
      await fillBasics(tester);
      await tester.enterText(find.byKey(const Key('nib-field')), '12345');
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(find.text('NIB harus 13 digit angka'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('a good NIB is saved after the business', (tester) async {
      final api = await pumpForm(tester);
      await fillBasics(tester);
      await tester.enterText(
        find.byKey(const Key('nib-field')),
        '1234567890123',
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(
        api.calls,
        containsAllInOrder(['business_register', 'business_set_nib']),
      );
      expect(api.params['business_set_nib']!['p_nib'], '1234567890123');
    });

    testWidgets('editing shows the saved NIB and says an admin checks it', (
      tester,
    ) async {
      await pumpForm(
        tester,
        existing: Business.fromMap(businessMap(nib: '1234567890123')),
      );
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('nib-field')),
      );
      expect(field.controller!.text, '1234567890123');
      expect(find.textContaining('dicek admin'), findsOneWidget);
    });
  });

  group('badge on the user side', () {
    testWidgets('detail and card show the blue tick only when verified', (
      tester,
    ) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_directory'] = [
          {...businessMap(id: 'b1', name: 'Terverifikasi')}..remove('status'),
          {
            ...businessMap(
              id: 'b2',
              name: 'Biasa',
              social: 'https://instagram.com/biasa',
            ),
          }..remove('status'),
        ]
        ..results['business_nib_verified_ids'] = [
          {'business_id': 'b1'},
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessDirectoryScreen(
            currentUser: ValueNotifier({'id': 'me'}),
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VerifiedBadge), findsOneWidget);
      await tester.tap(find.text('Terverifikasi'));
      await tester.pumpAndSettle();
      expect(find.byType(VerifiedBadge), findsOneWidget);
      // The number itself is never shown to other alumni.
      expect(find.textContaining('1234567890123'), findsNothing);
    });

    testWidgets('a typed but unchecked NIB shows no tick to the owner', (
      tester,
    ) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_my'] = [
          businessMap(status: 'approved', nib: '1234567890123'),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: MyBusinessesScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VerifiedBadge), findsNothing);
      expect(find.textContaining('Menunggu pengecekan NIB'), findsOneWidget);
    });

    testWidgets('owner of an approved business can still set the NIB', (
      tester,
    ) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_my'] = [businessMap(status: 'approved')]
        ..results['business_set_nib'] = businessMap(
          status: 'approved',
          nib: '1234567890123',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: MyBusinessesScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nib-edit-b1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('nib-dialog-field')),
        '1234567890123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(api.params['business_set_nib']!['p_nib'], '1234567890123');
    });
  });

  group('admin', () {
    Future<FakeAdminApi> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows, {
      List<Map<String, dynamic>> nibs = const [],
    }) async {
      tester.view.physicalSize = const Size(420, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeAdminApi()
        ..results['admin_businesses_list'] = rows
        ..results['admin_business_nibs'] = nibs
        ..results['admin_business_nib_verify'] = <dynamic>[];
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

    testWidgets('admin sees the NIB and can mark it verified', (tester) async {
      final api = await pump(
        tester,
        [businessMap()],
        nibs: [
          {'business_id': 'b1', 'nib': '1234567890123', 'nib_verified': false},
        ],
      );
      expect(find.textContaining('1234567890123'), findsOneWidget);
      expect(find.byType(VerifiedBadge), findsNothing);
      await tester.tap(find.byKey(const Key('nib-verify-b1')));
      await tester.pumpAndSettle();
      expect(api.params['admin_business_nib_verify'], {
        'p_admin': 'me',
        'p_business': 'b1',
        'p_verified': true,
      });
    });

    testWidgets('a verified NIB can be revoked', (tester) async {
      final api = await pump(
        tester,
        [businessMap()],
        nibs: [
          {'business_id': 'b1', 'nib': '1234567890123', 'nib_verified': true},
        ],
      );
      expect(find.byType(VerifiedBadge), findsOneWidget);
      await tester.tap(find.byKey(const Key('nib-verify-b1')));
      await tester.pumpAndSettle();
      expect(api.params['admin_business_nib_verify']!['p_verified'], false);
    });

    testWidgets('no NIB: no verify button', (tester) async {
      await pump(tester, [businessMap()]);
      expect(find.byKey(const Key('nib-verify-b1')), findsNothing);
    });
  });
}
