import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/business_directory_screen.dart';
import 'package:undip_alumni_connect/screens/business_form_screen.dart';
import 'package:undip_alumni_connect/screens/home_screen.dart';
import 'package:undip_alumni_connect/screens/my_businesses_screen.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/widgets/filter_dropdown.dart';

import 'support/fake_business_api.dart';
import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('bands', () {
    test('four bands follow PP 7/2021 and show the Rp amounts', () {
      expect(BusinessBand.values.map((b) => b.name), [
        'micro',
        'small',
        'medium',
        'large',
      ]);
      expect(BusinessBand.micro.range, contains('Rp 2 miliar'));
      expect(
        BusinessBand.small.range,
        allOf(contains('Rp 2 miliar'), contains('Rp 15 miliar')),
      );
      expect(
        BusinessBand.medium.range,
        allOf(contains('Rp 15 miliar'), contains('Rp 50 miliar')),
      );
      expect(BusinessBand.large.range, contains('Rp 50 miliar'));
      expect(BusinessBand.large.label, contains('not UMKM'));
    });
  });

  group('repository', () {
    test(
      'register sends the owner, links and band, and returns pending',
      () async {
        final api = FakeBusinessApi()
          ..results['business_register'] = businessMap();
        final b = await BusinessRepository(api).register(
          'me',
          const BusinessInput(
            name: 'Kopi Ahmad',
            description: 'Kopi',
            category: 'Food & Drink',
            socialLink: 'https://instagram.com/kopi_ahmad',
            band: BusinessBand.small,
          ),
        );
        expect(b.status, BusinessStatus.pending);
        expect(api.params['business_register']!['p_owner'], 'me');
        expect(api.params['business_register']!['p_band'], 'small');
        expect(api.params['business_register']!['p_website_link'], isNull);
        // The app never sends a status or an approved band.
        expect(
          api.params['business_register']!.keys.any(
            (k) => k.contains('status') || k.contains('approved'),
          ),
          isFalse,
        );
      },
    );

    test('update never sends a band', () async {
      final api = FakeBusinessApi()..results['business_update'] = businessMap();
      await BusinessRepository(api).update(
        'me',
        'b1',
        const BusinessInput(
          name: 'N1',
          description: 'd',
          category: 'Other',
          socialLink: 'https://x.example',
        ),
      );
      expect(
        api.params['business_update']!.keys.any((k) => k.contains('band')),
        isFalse,
      );
    });

    test('database codes become plain messages', () async {
      final cases = {
        'not_verified': BusinessErrorCode.notVerified,
        'link_in_use': BusinessErrorCode.linkInUse,
        'link_required': BusinessErrorCode.linkRequired,
        'locked': BusinessErrorCode.locked,
        'not_owner': BusinessErrorCode.notOwner,
      };
      for (final e in cases.entries) {
        final api = FakeBusinessApi()..throwOnCall = pgError(e.key);
        try {
          await BusinessRepository(api).mine('me');
          fail('should throw');
        } on BusinessException catch (ex) {
          expect(ex.code, e.value);
          expect(businessErrorMessage(ex), isNot(contains(e.key)));
        }
      }
    });

    test('directory rows without a status count as approved', () async {
      final api = FakeBusinessApi()
        ..results['business_directory'] = [
          {...businessMap(ownerName: 'Ahmad')}..remove('status'),
        ];
      final list = await BusinessRepository(api).directory('me');
      expect(list.single.isApproved, isTrue);
      expect(list.single.ownerName, 'Ahmad');
    });
  });

  group('registration form', () {
    Future<FakeBusinessApi> pumpForm(
      WidgetTester tester, {
      Business? existing,
    }) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_register'] = businessMap();
      api.results['business_update'] = businessMap();
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

    testWidgets('shows the four bands in plain words with Rp amounts', (
      tester,
    ) async {
      await pumpForm(tester);
      for (final b in BusinessBand.values) {
        expect(find.text(b.label), findsOneWidget);
        expect(find.text(b.range), findsOneWidget);
      }
      expect(
        find.textContaining('cannot change it after you submit'),
        findsOneWidget,
      );
    });

    testWidgets('empty form shows inline errors and calls nothing', (
      tester,
    ) async {
      final api = await pumpForm(tester);
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsWidgets);
      expect(find.text('Choose a category'), findsOneWidget);
      expect(
        find.text('Add an Instagram or social link, a website link, or both.'),
        findsOneWidget,
      );
      expect(find.text('Choose the yearly sales band.'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('a bad link is refused before sending', (tester) async {
      final api = await pumpForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name *'),
        'Kopi Ahmad',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Short description *'),
        'Kopi',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Instagram or social link'),
        'javascript:alert(1)',
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a link like https://instagram.com/yourshop'),
        findsOneWidget,
      );
      expect(api.calls, isEmpty);
    });

    testWidgets('a valid form registers, with the chosen band', (tester) async {
      final api = await pumpForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name *'),
        'Kopi Ahmad',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Short description *'),
        'Kopi dari Semarang',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food & Drink').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Instagram or social link'),
        'instagram.com/kopi_ahmad',
      );
      await tester.tap(find.byKey(const Key('band-small')));
      await tester.pump();
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(api.calls, ['business_register']);
      final p = api.params['business_register']!;
      expect(p['p_band'], 'small');
      expect(p['p_social_link'], 'https://instagram.com/kopi_ahmad');
      expect(p['p_category'], 'Food & Drink');
      expect(find.text(kBusinessSubmittedMessage), findsOneWidget);
    });

    testWidgets(
      'a link already used shows a clear message and the form stays',
      (tester) async {
        final api = await pumpForm(tester);
        api.throwOnCall = pgError('link_in_use');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Business name *'),
          'Tiruan',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Short description *'),
          'x',
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Other').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Website link'),
          'https://kopi.example.com',
        );
        await tester.tap(find.byKey(const Key('band-micro')));
        await tester.pump();
        await tester.tap(find.text('Submit for review'));
        await tester.pumpAndSettle();
        expect(
          find.text('Another business already uses one of these links.'),
          findsOneWidget,
        );
        expect(find.text('Submit for review'), findsOneWidget);
      },
    );

    testWidgets('editing: the band is shown but cannot be changed', (
      tester,
    ) async {
      final api = await pumpForm(
        tester,
        existing: Business.fromMap(
          businessMap(status: 'rejected', reason: 'Link tidak bisa dibuka'),
        ),
      );
      expect(find.textContaining('Link tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('cannot be changed'), findsOneWidget);
      final tile = tester.widget<RadioListTile<BusinessBand>>(
        find.byKey(const Key('band-micro')),
      );
      expect(tile.enabled, isFalse);
      await tester.tap(find.text('Save and send again'));
      await tester.pumpAndSettle();
      expect(api.calls, ['business_update']);
      expect(
        api.params['business_update']!.keys.any((k) => k.contains('band')),
        isFalse,
      );
    });
  });

  group('owner screen', () {
    testWidgets('shows status, rejection reason and an apply-again button', (
      tester,
    ) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_my'] = [
          businessMap(id: 'a', name: 'Pending Co', status: 'pending'),
          businessMap(
            id: 'b',
            name: 'Rejected Co',
            status: 'rejected',
            reason: 'Link tidak bisa dibuka',
          ),
          businessMap(
            id: 'c',
            name: 'Approved Co',
            status: 'approved',
            approvedBand: 'micro',
          ),
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
      expect(find.text('Waiting for review'), findsOneWidget);
      expect(find.text('Not approved'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Reason: Link tidak bisa dibuka'), findsOneWidget);
      expect(find.text('Approved band: Micro'), findsOneWidget);
      expect(find.text('Edit and apply again'), findsOneWidget);
      // An approved business cannot be edited by its owner.
      expect(find.byKey(const Key('edit-c')), findsNothing);
    });

    testWidgets('empty state', (tester) async {
      final api = FakeBusinessApi()..results['business_my'] = [];
      await tester.pumpWidget(
        MaterialApp(
          home: MyBusinessesScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('not registered a business yet'),
        findsOneWidget,
      );
    });
  });

  group('directory', () {
    Future<FakeBusinessApi> pumpDirectory(WidgetTester tester) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_directory'] = [
          businessMap(
            id: '1',
            name: 'Kopi Ahmad',
            category: 'Food & Drink',
            ownerName: 'Ahmad',
          ),
          businessMap(
            id: '2',
            name: 'Batik Siti',
            category: 'Fashion',
            ownerName: 'Siti',
            social: null,
            website: 'https://batiksiti.example.com',
          ),
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
      return api;
    }

    testWidgets('lists approved businesses and searches by name and category', (
      tester,
    ) async {
      final api = await pumpDirectory(tester);
      expect(api.params['business_directory']!['p_viewer'], 'me');
      expect(find.text('Kopi Ahmad'), findsOneWidget);
      expect(find.text('Batik Siti'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'batik');
      await tester.pumpAndSettle();
      expect(find.text('Kopi Ahmad'), findsNothing);
      expect(find.text('Batik Siti'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'food');
      await tester.pumpAndSettle();
      expect(find.text('Kopi Ahmad'), findsOneWidget);
      expect(find.text('Batik Siti'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No businesses match this search.'), findsOneWidget);
    });

    testWidgets('category chip filters', (tester) async {
      await pumpDirectory(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Fashion'));
      await tester.pumpAndSettle();
      expect(find.text('Kopi Ahmad'), findsNothing);
      expect(find.text('Batik Siti'), findsOneWidget);
    });

    testWidgets('detail shows links, no email, no phone', (tester) async {
      await pumpDirectory(tester);
      await tester.tap(find.text('Batik Siti'));
      await tester.pumpAndSettle();
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Instagram / social'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('a failed load shows a friendly message and Try again', (
      tester,
    ) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..throwOnCall = Exception('SocketException: Failed host lookup');
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessDirectoryScreen(
            currentUser: ValueNotifier({'id': 'me'}),
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    test('filter helper', () {
      final all = [
        Business.fromMap(businessMap(id: '1', name: 'Kopi Ahmad')),
        Business.fromMap(
          businessMap(id: '2', name: 'Batik', category: 'Fashion'),
        ),
      ];
      expect(
        applyBusinessFilters(all, query: '', category: kAllFilter).length,
        2,
      );
      expect(
        applyBusinessFilters(
          all,
          query: 'fashion',
          category: kAllFilter,
        ).single.name,
        'Batik',
      );
    });
  });

  group('Home entry', () {
    testWidgets(
      'real Businesses tile replaces the Business directory preview',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              currentUser: ValueNotifier({
                'id': 'me',
                'name': 'Ahmad Ramadhan',
              }),
              onOpenDirectory: () {},
              pages: fakePages(),
              api: FakeHomeApi(),
              marketplaceRepository: MarketplaceRepository(FakeApi()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('preview-business')), findsNothing);
        await tester.tap(find.byKey(const Key('tile-businesses')));
        await tester.pumpAndSettle();
        expect(find.text('PAGE Businesses'), findsOneWidget);
      },
    );
  });
}
