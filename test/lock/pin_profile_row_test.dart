import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/pin_settings_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

import '../support/fake_lock.dart';

/// Profile > PIN lock opens the PIN settings. It is only on my own profile, and
/// only where a lock exists (it is off on the public web build).
const me = {'id': 'me', 'name': 'Ahmad Ramadhan', 'email': 'a@example.com'};
const other = {'id': 'other', 'name': 'Siti Azizah', 'email': 's@example.com'};

Future<void> pump(
  WidgetTester tester, {
  required Map<String, dynamic> shown,
  required bool lockOn,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final lock = await makeRememberedLock();
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileDetailScreen(
        profile: shown,
        currentUser: ValueNotifier<Map<String, dynamic>>({...me}),
        // Other people's profiles are opened with showEditButton: false.
        showEditButton: shown['id'] == me['id'],
        chat: false,
        adminCheck: (_) async => false,
        lock: lockOn ? lock : makeLock(enabled: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('my profile has a PIN lock row that opens the settings', (
    tester,
  ) async {
    await pump(tester, shown: me, lockOn: true);
    final row = find.byKey(const Key('profile-pin'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(PinSettingsScreen), findsOneWidget);
  });

  testWidgets('no PIN lock row when there is no lock (web)', (tester) async {
    await pump(tester, shown: me, lockOn: false);
    expect(find.byKey(const Key('profile-pin')), findsNothing);
  });

  testWidgets('someone else\'s profile has no PIN lock row', (tester) async {
    await pump(tester, shown: other, lockOn: true);
    expect(find.byKey(const Key('profile-pin')), findsNothing);
  });
}
