import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/screens/admin_members_screen.dart';

import 'support/fake_admin_api.dart';

Map<String, dynamic> member({
  String id = 'm1',
  String name = 'Ahmad Ramadhan',
  String? suspendedAt,
  bool isAdmin = false,
}) => {
  'id': id,
  'name': name,
  'email': '$id@example.com',
  'major': 'Manajemen',
  'graduation_year': 2020,
  'current_role': null,
  'industry': null,
  'company': null,
  'city': null,
  'bio': null,
  'linkedin_url': null,
  'verification_status': 'verified',
  'suspended_at': suspendedAt,
  'suspended_reason': suspendedAt == null ? null : 'Akun palsu',
  'is_admin': isAdmin,
};

Future<FakeAdminApi> open(
  WidgetTester tester,
  List<Map<String, dynamic>> rows, {
  Size s = const Size(420, 1800),
}) async {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeAdminApi()..results['admin_members_list'] = rows;
  await tester.pumpWidget(
    MaterialApp(
      home: AdminMembersScreen(adminId: 'me', repository: AdminRepository(api)),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  test('repository sends suspend and jurusan fix', () async {
    final api = FakeAdminApi();
    final repo = AdminRepository(api);
    await repo.setMemberSuspended('me', 'm1', suspend: true, reason: ' spam ');
    expect(api.params['admin_member_set_suspended'], {
      'p_admin': 'me',
      'p_profile': 'm1',
      'p_suspend': true,
      'p_reason': 'spam',
    });
    await repo.setMemberMajor('me', 'm1', ' Akuntansi ');
    expect(api.params['admin_member_set_major'], {
      'p_admin': 'me',
      'p_profile': 'm1',
      'p_major': 'Akuntansi',
    });
  });

  test('member list rows carry status', () {
    final m = AdminMember.fromMap(
      member(suspendedAt: '2026-11-16T10:00:00Z', isAdmin: true),
    );
    expect(m.isSuspended, isTrue);
    expect(m.isAdmin, isTrue);
    expect(m.suspendedReason, 'Akun palsu');
  });

  testWidgets('list shows tags and the status filter narrows it', (
    tester,
  ) async {
    await open(tester, [
      member(),
      member(
        id: 'm2',
        name: 'Siti Azizah',
        suspendedAt: '2026-11-16T10:00:00Z',
      ),
      member(id: 'm3', name: 'Clara Putri', isAdmin: true),
    ]);
    expect(find.byKey(const Key('tag-suspended-m2')), findsOneWidget);
    expect(find.byKey(const Key('tag-admin-m3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('members-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ditangguhkan').last);
    await tester.pumpAndSettle();
    expect(find.text('Siti Azizah'), findsOneWidget);
    expect(find.text('Ahmad Ramadhan'), findsNothing);
    expect(find.text('Clara Putri'), findsNothing);
  });

  testWidgets('suspend asks for a reason first and cancel sends nothing', (
    tester,
  ) async {
    final api = await open(tester, [member()]);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('member-suspend')));
    await tester.tap(find.byKey(const Key('member-suspend')));
    await tester.pumpAndSettle();
    // Empty reason is refused on screen.
    await tester.tap(find.byKey(const Key('admin-reason-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Alasan wajib diisi.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-reason-cancel')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('admin_member_set_suspended')));
    // Now with a reason.
    await tester.tap(find.byKey(const Key('member-suspend')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin-reason')), 'Akun palsu');
    await tester.tap(find.byKey(const Key('admin-reason-ok')));
    await tester.pumpAndSettle();
    expect(api.params['admin_member_set_suspended'], {
      'p_admin': 'me',
      'p_profile': 'm1',
      'p_suspend': true,
      'p_reason': 'Akun palsu',
    });
    // The screen stays open. Going back reloads the list.
    expect(find.byKey(const Key('member-suspend')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      api.calls.where((c) => c == 'admin_members_list').length,
      greaterThanOrEqualTo(2),
    );
  });

  testWidgets('a suspended member can be activated after a confirm', (
    tester,
  ) async {
    final api = await open(tester, [
      member(suspendedAt: '2026-11-16T10:00:00Z'),
    ]);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('member-suspended-note')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('member-suspend')));
    await tester.tap(find.byKey(const Key('member-suspend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-unsuspend')));
    await tester.pumpAndSettle();
    expect(api.params['admin_member_set_suspended']?['p_suspend'], false);
  });

  testWidgets('admins and yourself have no suspend button', (tester) async {
    await open(tester, [
      member(id: 'm3', name: 'Clara Putri', isAdmin: true),
      member(id: 'me', name: 'Saya Sendiri'),
    ]);
    for (final name in ['Clara Putri', 'Saya Sendiri']) {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('member-suspend')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('jurusan fix picks from the list and saves', (tester) async {
    final api = await open(tester, [member()]);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('member-major')));
    await tester.tap(find.byKey(const Key('member-major')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('major-Akuntansi')));
    await tester.pumpAndSettle();
    expect(api.params['admin_member_set_major'], {
      'p_admin': 'me',
      'p_profile': 'm1',
      'p_major': 'Akuntansi',
    });
  });

  testWidgets('no NIM anywhere on the member screens', (tester) async {
    await open(tester, [member()]);
    expect(find.textContaining('NIM'), findsNothing);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('NIM'), findsNothing);
  });

  for (final s in [const Size(360, 740), const Size(1440, 900)]) {
    testWidgets('list and account section fit ${s.width.toInt()} px', (
      tester,
    ) async {
      await open(tester, [
        member(suspendedAt: '2026-11-16T10:00:00Z', isAdmin: false),
        member(id: 'm3', name: 'Clara Putri', isAdmin: true),
      ], s: s);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ahmad Ramadhan'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
