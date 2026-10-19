import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/admin_announcements_screen.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_marketplace_api.dart';

Map<String, dynamic> row(
  String id,
  String title, {
  String body = 'Isi pengumuman',
  String? by = 'Gilang',
  Duration age = const Duration(days: 1),
}) => {
  'id': id,
  'title': title,
  'body': body,
  'posted_by_name': by,
  'created_at': DateTime.now().subtract(age).toIso8601String(),
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('repository', () {
    test('create sends the admin id and trimmed text', () async {
      final api = FakeAdminApi()..results['admin_announcement_create'] = 'id1';
      await AdminRepository(api).createAnnouncement(
        'me',
        title: '  Reuni  ',
        body: ' Sabtu depan ',
      );
      expect(api.params['admin_announcement_create'], {
        'p_admin': 'me',
        'p_title': 'Reuni',
        'p_body': 'Sabtu depan',
      });
    });

    test('list parses rows', () async {
      final api = FakeAdminApi()
        ..results['admin_announcement_list'] = [row('a', 'Reuni')];
      final list = await AdminRepository(api).announcements('me');
      expect(api.params['admin_announcement_list'], {'p_admin': 'me'});
      expect(list.single.title, 'Reuni');
      expect(list.single.postedByName, 'Gilang');
    });

    test('invalid_input becomes a plain message', () {
      expect(
        adminErrorMessage(
          const AdminException(AdminErrorCode.invalidInput, 'invalid_input'),
        ),
        contains('Title'),
      );
    });
  });

  group('screen', () {
    Future<FakeAdminApi> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows,
    ) async {
      phone(tester);
      final api = FakeAdminApi()
        ..results['admin_announcement_list'] = rows
        ..results['admin_announcement_create'] = 'new';
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAnnouncementsScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('search and Period narrow the list', (tester) async {
      await pump(tester, [
        row('a', 'Reuni akbar', age: const Duration(days: 2)),
        row('b', 'Beasiswa', age: const Duration(days: 60)),
      ]);
      expect(find.text('Reuni akbar'), findsOneWidget);
      expect(find.text('Beasiswa'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('admin-announcements-search')),
          matching: find.byType(TextField),
        ),
        'beasiswa',
      );
      await tester.pump();
      expect(find.text('Reuni akbar'), findsNothing);
      expect(find.text('Beasiswa'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('admin-announcements-search')),
          matching: find.byType(TextField),
        ),
        '',
      );
      await tester.tap(find.byKey(const Key('admin-announcements-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last 30 days').last);
      await tester.pumpAndSettle();
      expect(find.text('Reuni akbar'), findsOneWidget);
      expect(find.text('Beasiswa'), findsNothing);
    });

    testWidgets('empty form is refused without a database call', (
      tester,
    ) async {
      final api = await pump(tester, []);
      await tester.tap(find.byKey(const Key('announcement-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('announcement-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a title.'), findsOneWidget);
      expect(find.text('Enter the message.'), findsOneWidget);
      expect(api.calls.contains('admin_announcement_create'), isFalse);
    });

    testWidgets('posting sends the text and reloads the list', (tester) async {
      final api = await pump(tester, []);
      await tester.tap(find.byKey(const Key('announcement-new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('announcement-title')),
        'Reuni',
      );
      await tester.enterText(
        find.byKey(const Key('announcement-body')),
        'Sabtu depan',
      );
      api.calls.clear();
      await tester.tap(find.byKey(const Key('announcement-submit')));
      await tester.pumpAndSettle();
      expect(api.params['admin_announcement_create'], {
        'p_admin': 'me',
        'p_title': 'Reuni',
        'p_body': 'Sabtu depan',
      });
      expect(api.calls, contains('admin_announcement_list'));
      expect(find.byKey(const Key('announcement-title')), findsNothing);
    });

    testWidgets('a refused post keeps the form and says why', (tester) async {
      final api = await pump(tester, []);
      await tester.tap(find.byKey(const Key('announcement-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('announcement-title')), 'A');
      await tester.enterText(find.byKey(const Key('announcement-body')), 'B');
      api.throwOnCall = const AdminException(
        AdminErrorCode.notAdmin,
        'not_admin',
      );
      await tester.tap(find.byKey(const Key('announcement-submit')));
      await tester.pumpAndSettle();
      expect(find.text('You are not an admin.'), findsOneWidget);
      expect(find.byKey(const Key('announcement-title')), findsOneWidget);
    });
  });

  testWidgets('Admin home lists Announcements', (tester) async {
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
    expect(find.byKey(const Key('admin-announcements')), findsOneWidget);
  });
}
