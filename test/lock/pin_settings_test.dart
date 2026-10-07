import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_config.dart';
import 'package:undip_alumni_connect/lock/pin_settings_screen.dart';

import '../support/fake_lock.dart';

/// Profile > PIN lock. There was no way to change or remove the PIN after the
/// first setup. Changing or removing needs the current PIN.
Future<void> pump(WidgetTester tester, PinSettingsScreen screen) async {
  tester.view.physicalSize = const Size(420, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no PIN yet: offers to set one, nothing to change or remove', (
    tester,
  ) async {
    final lock = await makeRememberedLock(withPin: false);
    await pump(tester, PinSettingsScreen(lock: lock));
    expect(find.byKey(const Key('pin-set')), findsOneWidget);
    expect(find.byKey(const Key('pin-change')), findsNothing);
    expect(find.byKey(const Key('pin-remove')), findsNothing);
  });

  testWidgets('a PIN is set: offers change and remove, not set', (
    tester,
  ) async {
    final lock = await makeRememberedLock();
    await pump(tester, PinSettingsScreen(lock: lock));
    expect(find.byKey(const Key('pin-change')), findsOneWidget);
    expect(find.byKey(const Key('pin-remove')), findsOneWidget);
    expect(find.byKey(const Key('pin-set')), findsNothing);
  });

  testWidgets('remove asks for the current PIN first', (tester) async {
    final lock = await makeRememberedLock();
    await pump(tester, PinSettingsScreen(lock: lock));
    await tester.tap(find.byKey(const Key('pin-remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pin-verify-title')), findsOneWidget);
    expect(await lock.hasPin(), isTrue); // nothing removed yet
  });

  testWidgets(
    'a wrong current PIN removes nothing and says how many tries are left',
    (tester) async {
      final lock = await makeRememberedLock();
      await pump(tester, PinSettingsScreen(lock: lock));
      await tester.tap(find.byKey(const Key('pin-remove')));
      await tester.pumpAndSettle();
      await enterPin(tester, '000001');
      await tester.pumpAndSettle();
      expect(await lock.hasPin(), isTrue);
      expect(find.byKey(const Key('pin-verify-error')), findsOneWidget);
      expect(find.textContaining('${kMaxPinAttempts - 1}'), findsWidgets);
    },
  );

  testWidgets('right PIN, then confirm, removes the PIN', (tester) async {
    final lock = await makeRememberedLock();
    await pump(tester, PinSettingsScreen(lock: lock));
    await tester.tap(find.byKey(const Key('pin-remove')));
    await tester.pumpAndSettle();
    await enterPin(tester, testPin);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pin-remove-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pin-remove-confirm')));
    await tester.pumpAndSettle();
    expect(await lock.hasPin(), isFalse);
    expect((await lock.load())!.profileId, 'p1'); // still remembered
    expect(find.byKey(const Key('pin-set')), findsOneWidget);
  });

  testWidgets('cancelling the confirmation keeps the PIN', (tester) async {
    final lock = await makeRememberedLock();
    await pump(tester, PinSettingsScreen(lock: lock));
    await tester.tap(find.byKey(const Key('pin-remove')));
    await tester.pumpAndSettle();
    await enterPin(tester, testPin);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await lock.hasPin(), isTrue);
  });

  testWidgets('change: right current PIN, then the new-PIN flow opens', (
    tester,
  ) async {
    final lock = await makeRememberedLock();
    await pump(tester, PinSettingsScreen(lock: lock));
    await tester.tap(find.byKey(const Key('pin-change')));
    await tester.pumpAndSettle();
    await enterPin(tester, testPin);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pin-setup')), findsOneWidget);
    // New PIN twice. The old one stops working, the new one works.
    await enterPin(tester, '739104');
    await tester.pumpAndSettle();
    await enterPin(tester, '739104');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pin-setup')), findsNothing);
    expect((await lock.checkPin('739104')).runtimeType.toString(), 'PinOk');
  });
}
