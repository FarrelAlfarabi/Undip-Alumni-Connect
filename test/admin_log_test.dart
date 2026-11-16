import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/screens/admin_log_screen.dart';

import 'support/fake_admin_api.dart';

Future<FakeAdminApi> open(
  WidgetTester tester, {
  Size s = const Size(420, 1200),
}) async {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeAdminApi()
    ..results['admin_actions_search'] = [
      {
        'id': 'x1',
        'admin_name': 'Clara',
        'action': 'member_remove',
        'target_type': 'profile',
        'detail': 'Akun palsu',
        'created_at': '2026-11-16T10:00:00Z',
      },
      {
        'id': 'x2',
        'admin_name': 'Clara',
        'action': 'something_new',
        'created_at': '2026-11-16T09:00:00Z',
      },
    ];
  await tester.pumpWidget(
    MaterialApp(
      home: AdminLogScreen(adminId: 'me', repository: AdminRepository(api)),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('shows plain labels and unknown codes as they are', (
    tester,
  ) async {
    final api = await open(tester);
    expect(find.text('Anggota dan datanya dihapus'), findsOneWidget);
    expect(find.text('something_new'), findsOneWidget);
    expect(api.params['admin_actions_search']?['p_admin'], 'me');
  });

  testWidgets('search, kind and period go to the database', (tester) async {
    final api = await open(tester);
    await tester.enterText(find.byKey(const Key('log-search')), 'palsu');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(api.params['admin_actions_search']?['p_search'], 'palsu');

    await tester.tap(find.byKey(const ValueKey('log-kind:All')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anggota').last);
    await tester.pumpAndSettle();
    expect(api.params['admin_actions_search']?['p_action_prefix'], 'member_');

    await tester.tap(find.byKey(const ValueKey('log-period:All')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 hari').last);
    await tester.pumpAndSettle();
    final since = DateTime.parse(
      api.params['admin_actions_search']!['p_since'] as String,
    );
    expect(DateTime.now().difference(since).inDays, 7);

    await tester.tap(find.text('Hapus filter'));
    await tester.pumpAndSettle();
    expect(api.params['admin_actions_search']?['p_search'], isNull);
    expect(api.params['admin_actions_search']?['p_action_prefix'], isNull);
    expect(api.params['admin_actions_search']?['p_since'], isNull);
  });

  for (final s in [const Size(360, 740), const Size(1440, 900)]) {
    testWidgets('fits ${s.width.toInt()} px', (tester) async {
      await open(tester, s: s);
      expect(tester.takeException(), isNull);
    });
  }
}
