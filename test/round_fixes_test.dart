import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/screens/admin_feedback_screen.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/business_form_screen.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';
import 'package:undip_alumni_connect/util/safe_url.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('Instagram handle', () {
    test('@username becomes an instagram.com link', () {
      expect(
        parseInstagram('@kopi_ahmad').toString(),
        'https://instagram.com/kopi_ahmad',
      );
      expect(
        parseInstagram('  @kopi.ahmad ').toString(),
        'https://instagram.com/kopi.ahmad',
      );
    });

    test('a full link still works, bad handles are refused', () {
      expect(
        parseInstagram('instagram.com/kopi_ahmad').toString(),
        'https://instagram.com/kopi_ahmad',
      );
      expect(parseInstagram('@'), isNull);
      expect(parseInstagram('@kopi ahmad'), isNull);
      expect(parseInstagram('@kopi/ahmad'), isNull);
      expect(parseInstagram('@${'a' * 31}'), isNull);
      expect(parseInstagram('javascript:alert(1)'), isNull);
    });
  });

  group('business form: Instagram required, website optional', () {
    Future<FakeBusinessApi> pumpForm(WidgetTester tester) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_register'] = businessMap();
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessFormScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> fillRest(WidgetTester tester) async {
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
      await tester.tap(find.byKey(const Key('band-small')));
      await tester.pump();
    }

    testWidgets('@username is saved as an instagram.com link', (tester) async {
      final api = await pumpForm(tester);
      await fillRest(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Instagram *'),
        '@kopi_ahmad',
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(api.calls, ['business_register']);
      final p = api.params['business_register']!;
      expect(p['p_social_link'], 'https://instagram.com/kopi_ahmad');
      expect(p['p_website_link'], isNull);
    });

    testWidgets('a website alone is not enough', (tester) async {
      final api = await pumpForm(tester);
      await fillRest(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Website link (optional)'),
        'https://kopi.example.com',
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('the website can be left empty or filled in', (tester) async {
      final api = await pumpForm(tester);
      await fillRest(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Instagram *'),
        '@kopi_ahmad',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Website link (optional)'),
        'kopi.example.com',
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(
        api.params['business_register']!['p_website_link'],
        'https://kopi.example.com',
      );
    });

    test('the server code link_required asks for Instagram', () {
      final msg = businessErrorMessage(
        const BusinessException(BusinessErrorCode.linkRequired, 'x'),
      );
      expect(msg, contains('Instagram'));
      expect(msg, isNot(contains('or both')));
    });
  });

  group('admin search and filters', () {
    Future<FakeAdminApi> pumpBusinesses(
      WidgetTester tester,
      List<Map<String, dynamic>> rows,
    ) async {
      tall(tester);
      final api = FakeAdminApi()..results['admin_businesses_list'] = rows;
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

    testWidgets('Businesses: search by name, owner or link', (tester) async {
      await pumpBusinesses(tester, [
        businessMap(id: 'a', name: 'Kopi Ahmad', ownerName: 'Ahmad'),
        businessMap(
          id: 'b',
          name: 'Batik Siti',
          ownerName: 'Siti',
          social: 'https://instagram.com/batiksiti',
        ),
      ]);
      expect(find.text('Kopi Ahmad'), findsOneWidget);
      expect(find.text('Batik Siti'), findsOneWidget);

      final search = find.byKey(const Key('admin-business-search'));
      await tester.enterText(search, 'siti');
      await tester.pumpAndSettle();
      expect(find.text('Kopi Ahmad'), findsNothing);
      expect(find.text('Batik Siti'), findsOneWidget);

      await tester.enterText(search, 'kopi_ahmad');
      await tester.pumpAndSettle();
      expect(find.text('Kopi Ahmad'), findsOneWidget);
      expect(find.text('Batik Siti'), findsNothing);

      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches.'), findsOneWidget);
    });

    testWidgets('Businesses: filter by category, search needs no new load', (
      tester,
    ) async {
      final api = await pumpBusinesses(tester, [
        businessMap(id: 'a', name: 'Kopi Ahmad', category: 'Food & Drink'),
        businessMap(id: 'b', name: 'Batik Siti', category: 'Fashion'),
      ]);
      await tester.tap(find.byKey(const Key('admin-business-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fashion').last);
      await tester.pumpAndSettle();
      expect(find.text('Kopi Ahmad'), findsNothing);
      expect(find.text('Batik Siti'), findsOneWidget);
      expect(
        api.calls.where((c) => c == 'admin_businesses_list'),
        hasLength(1),
      );
    });

    testWidgets('Feedback: search by message, name or screen', (tester) async {
      tall(tester);
      Map<String, dynamic> row(String id, String msg, String screen) => {
        'id': id,
        'profile_name': 'Siti',
        'message': msg,
        'error_text': null,
        'screen': screen,
        'app_version': '0.9.0',
        'build_number': '7',
        'platform': 'android',
        'status': 'new',
        'created_at': '2026-10-02T08:00:00Z',
      };
      final api = FakeAdminApi()
        ..results['admin_feedback_list'] = [
          row('a', 'tombol macet', 'Job Board'),
          row('b', 'foto gagal', 'Marketplace'),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: AdminFeedbackScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feedback-a')), findsOneWidget);
      expect(find.byKey(const Key('feedback-b')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('admin-feedback-search')),
        'marketplace',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feedback-a')), findsNothing);
      expect(find.byKey(const Key('feedback-b')), findsOneWidget);
    });
  });

  group('directory industry filter', () {
    Future<void> pumpDirectory(WidgetTester tester) async {
      tall(tester);
      Map<String, dynamic> p(String id, String name, String industry) => {
        'id': id,
        'name': name,
        'major': 'Manajemen',
        'graduation_year': 2020,
        'industry': industry,
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectoryScreen(
              currentUser: ValueNotifier({'id': 'me'}),
              fetchAlumni: () async => [
                p('1', 'Ayu Lestari', 'Information Technology'),
                p('2', 'Budi Santoso', 'Banking and Finance'),
                p('3', 'Citra Dewi', 'Insurance'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder arrow() => find.descendant(
      of: find.byKey(const Key('directory-industry')),
      matching: find.byIcon(Icons.arrow_drop_down),
    );

    Finder field() => find.descendant(
      of: find.byKey(const Key('directory-industry')),
      matching: find.byType(TextField),
    );

    testWidgets('type to narrow the list, then pick', (tester) async {
      await pumpDirectory(tester);
      await tester.tap(field());
      await tester.pumpAndSettle();
      await tester.enterText(field(), 'Bank');
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton).hitTestable(), findsOneWidget);
      await tester.tap(find.byType(MenuItemButton).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Ayu Lestari'), findsNothing);
      expect(find.text('Citra Dewi'), findsNothing);
    });

    testWidgets('it is still a dropdown: open and pick without typing', (
      tester,
    ) async {
      await pumpDirectory(tester);
      await tester.tap(arrow().first);
      await tester.pumpAndSettle();
      expect(
        find.byType(MenuItemButton).hitTestable(),
        findsNWidgets(4),
      ); // All + 3
      await tester.tap(find.text('Insurance').last);
      await tester.pumpAndSettle();
      expect(find.text('Citra Dewi'), findsOneWidget);
      expect(find.text('Ayu Lestari'), findsNothing);
    });

    testWidgets('Clear filters resets the industry box', (tester) async {
      await pumpDirectory(tester);
      await tester.tap(arrow().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insurance').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field()).controller!.text, 'All');
      expect(find.text('Ayu Lestari'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
    });
  });

  group('web: no zoom on form fields', () {
    test('index.html has a viewport meta that stops focus zoom', () {
      final html = File('web/index.html').readAsStringSync();
      final meta = RegExp(r'<meta[^>]*name="viewport"[^>]*>')
          .firstMatch(html)
          ?.group(0);
      expect(meta, isNotNull, reason: 'no viewport meta in web/index.html');
      expect(meta, contains('width=device-width'));
      expect(meta, contains('maximum-scale=1'));
      expect(meta, contains('user-scalable=no'));
    });
  });
}
