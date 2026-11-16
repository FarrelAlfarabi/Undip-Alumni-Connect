import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/screens/admin_admins_screen.dart';

import 'support/fake_admin_api.dart';

List<Map<String, dynamic>> admins() => [
  {
    'profile_id': 'owner',
    'name': 'Farrel Owner',
    'email': 'o@example.com',
    'is_owner': true,
    'added_at': '2026-10-05T00:00:00Z',
  },
  {'profile_id': 'me', 'name': 'Saya Admin', 'is_owner': false},
  {'profile_id': 'a2', 'name': 'Admin Dua', 'is_owner': false},
];

Future<FakeAdminApi> open(
  WidgetTester tester, {
  Size s = const Size(420, 1400),
}) async {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeAdminApi()
    ..results['admin_admins_list'] = admins()
    ..results['admin_members_list'] = [
      {
        'id': 'm1',
        'name': 'Calon Admin',
        'email': 'c@example.com',
        'verification_status': 'verified',
        'is_admin': false,
      },
      {
        'id': 'm2',
        'name': 'Ditangguhkan Orang',
        'verification_status': 'verified',
        'suspended_at': '2026-11-16T00:00:00Z',
        'is_admin': false,
      },
      {
        'id': 'a2',
        'name': 'Admin Dua',
        'verification_status': 'verified',
        'is_admin': true,
      },
    ];
  await tester.pumpWidget(
    MaterialApp(
      home: AdminAdminsScreen(adminId: 'me', repository: AdminRepository(api)),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('only removable admins get a remove button', (tester) async {
    await open(tester);
    expect(find.text('Farrel Owner'), findsOneWidget);
    expect(find.byKey(const Key('remove-admin-owner')), findsNothing);
    expect(find.byKey(const Key('remove-admin-me')), findsNothing);
    expect(find.byKey(const Key('remove-admin-a2')), findsOneWidget);
  });

  testWidgets('remove asks first; cancel sends nothing', (tester) async {
    final api = await open(tester);
    await tester.tap(find.byKey(const Key('remove-admin-a2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('admin_admin_remove')));
    await tester.tap(find.byKey(const Key('remove-admin-a2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-remove-admin')));
    await tester.pumpAndSettle();
    expect(api.params['admin_admin_remove'], {
      'p_admin': 'me',
      'p_profile': 'a2',
    });
  });

  testWidgets('add picks only active non-admin members, then confirms', (
    tester,
  ) async {
    final api = await open(tester);
    await tester.tap(find.byKey(const Key('add-admin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick-m1')), findsOneWidget);
    expect(find.byKey(const Key('pick-m2')), findsNothing);
    expect(find.byKey(const Key('pick-a2')), findsNothing);
    await tester.tap(find.byKey(const Key('pick-m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-add-admin')));
    await tester.pumpAndSettle();
    expect(api.params['admin_admin_add'], {'p_admin': 'me', 'p_profile': 'm1'});
  });

  testWidgets('a refusal shows a plain sentence', (tester) async {
    final api = await open(tester);
    await tester.tap(find.byKey(const Key('remove-admin-a2')));
    await tester.pumpAndSettle();
    api.throwOnCall = const AdminException(
      AdminErrorCode.ownerProtected,
      'owner_protected',
    );
    await tester.tap(find.byKey(const Key('confirm-remove-admin')));
    await tester.pumpAndSettle();
    expect(
      find.text('Admin pemilik hanya bisa diubah lewat dashboard Supabase.'),
      findsOneWidget,
    );
  });

  for (final s in [const Size(360, 740), const Size(1440, 900)]) {
    testWidgets('fits ${s.width.toInt()} px', (tester) async {
      await open(tester, s: s);
      expect(tester.takeException(), isNull);
    });
  }
}
