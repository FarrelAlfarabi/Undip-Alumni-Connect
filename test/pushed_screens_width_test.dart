import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/block_list.dart';
import 'package:undip_alumni_connect/platform/breakpoints.dart';
import 'package:undip_alumni_connect/screens/blocked_users_screen.dart';

import 'support/fake_report_api.dart';

/// Pushed list screens must stay in the centred column on wide windows,
/// like the screens inside the app shell.
void main() {
  testWidgets('Blocked users list stays within the tablet column',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeBlockApi()
      ..results['user_blocks_list'] = [
        {
          'blocked_id': 'u2',
          'name': 'Siti Azizah',
          'created_at': '2026-10-01T00:00:00Z',
        },
      ];
    final list = BlockList(BlockRepository(api))..blocked.value = {'u2'};
    await tester.pumpWidget(
      MaterialApp(
        home: BlockedUsersScreen(
          currentUserId: 'me',
          repository: BlockRepository(api),
          blockList: list,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('unblock-u2'));
    expect(tile, findsOneWidget);
    final width = tester.getSize(find.byType(ListView).first).width;
    expect(width, lessThanOrEqualTo(maxContentWidth(ScreenStep.tablet)));
  });
}
