import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/screens/admin_members_screen.dart';

import 'support/fake_admin_api.dart';

Map<String, dynamic> member({
  String id = 'm1',
  String name = 'Akun Palsu',
  bool isAdmin = false,
}) => {
  'id': id,
  'name': name,
  'email': '$id@example.com',
  'major': 'Manajemen',
  'graduation_year': 2020,
  'verification_status': 'verified',
  'is_admin': isAdmin,
};

Future<FakeAdminApi> open(
  WidgetTester tester,
  List<Map<String, dynamic>> rows,
) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeAdminApi()..results['admin_members_list'] = rows;
  await tester.pumpWidget(
    MaterialApp(
      home: AdminMembersScreen(adminId: 'me', repository: AdminRepository(api)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(rows.first['name'] as String));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  test('repository sends the removal and reads the counts', () async {
    final api = FakeAdminApi()
      ..results['admin_member_remove'] = {
        'deleted': true,
        'removed': {'businesses': 1, 'jobs': 2},
      };
    final counts = await AdminRepository(api)
        .removeMember('me', 'm1', ' palsu ');
    expect(api.params['admin_member_remove'], {
      'p_admin': 'me',
      'p_profile': 'm1',
      'p_reason': 'palsu',
    });
    expect(counts, {'businesses': 1, 'jobs': 2});
  });

  testWidgets('remove needs a reason and the word HAPUS', (tester) async {
    final api = await open(tester, [member()]);
    await tester.tap(find.byKey(const Key('member-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-remove')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin-reason')), 'Akun palsu');
    await tester.enterText(find.byKey(const Key('admin-confirm-word')), 'hapu');
    await tester.tap(find.byKey(const Key('admin-reason-ok')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('admin_member_remove')));
    expect(find.text('Ketik HAPUS persis.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('admin-confirm-word')),
      'hapus',
    );
    await tester.tap(find.byKey(const Key('admin-reason-ok')));
    await tester.pumpAndSettle();
    expect(api.params['admin_member_remove'], {
      'p_admin': 'me',
      'p_profile': 'm1',
      'p_reason': 'Akun palsu',
    });
    expect(find.text('Akun Palsu dan datanya sudah dihapus.'), findsOneWidget);
  });

  testWidgets('cancel removes nothing', (tester) async {
    final api = await open(tester, [member()]);
    await tester.tap(find.byKey(const Key('member-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-reason-cancel')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('admin_member_remove')));
  });

  testWidgets('no remove button for admins or yourself', (tester) async {
    await open(tester, [member(id: 'a1', name: 'Admin Lain', isAdmin: true)]);
    expect(find.byKey(const Key('member-remove')), findsNothing);
  });
}
