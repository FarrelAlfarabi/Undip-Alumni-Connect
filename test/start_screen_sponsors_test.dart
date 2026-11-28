import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';
import 'package:undip_alumni_connect/widgets/sponsor_grid.dart';
import 'package:undip_alumni_connect/widgets/sponsor_slot.dart';

import 'support/fake_home.dart';
import 'support/fake_lock.dart';

Future<void> pumpAt(WidgetTester tester, Size size, Widget home) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pump();
  await tester.pump();
}

Future<List<Map<String, dynamic>>> two() async => [
  sponsorMap(1),
  sponsorMap(2),
];
Future<List<Map<String, dynamic>>> none() async => [];
Future<List<Map<String, dynamic>>> boom() async => throw Exception('offline');

Future<Widget> lockScreen(SponsorLoader loader) async {
  final lock = await makeRememberedLock();
  return LockScreen(
    lock: lock,
    user: (await lock.load())!,
    onUnlocked: () async {},
    onSwitchAccount: () async {},
    onForgotPin: () async {},
    onLockedOut: () async {},
    onContinue: () async {},
    autoBiometric: false,
    sponsorLoader: loader,
  );
}

void main() {
  test('grid columns: few sponsors in one row, at most 4 per row', () {
    expect(sponsorGridColumns(1), 1);
    expect(sponsorGridColumns(3), 3);
    expect(sponsorGridColumns(4), 4);
    expect(sponsorGridColumns(6), 3);
    expect(sponsorGridColumns(7), 4);
    expect(sponsorGridColumns(10), 4);
  });

  const sizes = {
    'phone': Size(390, 844),
    'small phone': Size(360, 640),
    'desktop': Size(1440, 900),
  };
  for (final e in sizes.entries) {
    testWidgets('Welcome shows sponsors at the bottom, ${e.key}', (t) async {
      await pumpAt(t, e.value, WelcomeScreen(sponsorLoader: two));
      expect(find.byType(SponsorGrid), findsOneWidget);
      final banner = t.getRect(find.byType(SponsorGrid));
      if (e.value.width < 1000) {
        expect(banner.bottom, greaterThan(e.value.height * 0.6));
      } else {
        // Wide screen: inside the centred card, at its bottom.
        expect(
          t.getRect(find.byKey(const Key('auth-card'))).bottom,
          greaterThanOrEqualTo(banner.bottom),
        );
      }
      expect(
        t.getRect(find.byType(Wrap)).width,
        lessThanOrEqualTo(kSponsorSlotMaxWidth),
      );
      expect(find.text('Mulai'), findsOneWidget);
      // The button stays on screen, above the sponsor card (no scrolling
      // needed on a normal phone).
      if (e.value.height >= 800) {
        expect(
          t.getRect(find.text('Mulai')).bottom,
          lessThanOrEqualTo(banner.top),
        );
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('Lock screen shows sponsors at the bottom, ${e.key}', (
      t,
    ) async {
      await pumpAt(t, e.value, await lockScreen(two));
      expect(find.byType(SponsorGrid), findsOneWidget);
      final banner = t.getRect(find.byType(SponsorGrid));
      if (e.value.width < 1000) {
        expect(banner.bottom, greaterThan(e.value.height * 0.6));
      } else {
        expect(
          t.getRect(find.byKey(const Key('auth-card'))).bottom,
          greaterThanOrEqualTo(banner.bottom),
        );
      }
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('no sponsors or a failed load: screens are unchanged', (t) async {
    await pumpAt(t, const Size(390, 844), WelcomeScreen(sponsorLoader: none));
    expect(find.byType(SponsorGrid), findsNothing);
    await pumpAt(t, const Size(390, 844), WelcomeScreen(sponsorLoader: boom));
    expect(find.byType(SponsorGrid), findsNothing);
    expect(find.text('Mulai'), findsOneWidget);
    await pumpAt(t, const Size(390, 844), await lockScreen(boom));
    expect(find.byType(SponsorGrid), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('a view is counted once per sponsor, a tap only after Buka', (
    t,
  ) async {
    final events = <String>[];
    final opened = <String?>[];
    await pumpAt(
      t,
      const Size(390, 844),
      Scaffold(
        body: SponsorSlot(
          loader: two,
          sender: (id, kind) async => events.add('$kind:$id'),
          openLink: (u) async {
            opened.add(u);
            return true;
          },
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    expect(events.where((e) => e.startsWith('view:')).length, 2);
    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Batal'));
    await t.pumpAndSettle();
    expect(events.any((e) => e.startsWith('tap:')), isFalse);
    expect(opened, isEmpty);
    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Buka'));
    await t.pumpAndSettle();
    expect(events.any((e) => e.startsWith('tap:')), isTrue);
    expect(opened.single, startsWith('https://sponsor'));
  });

  testWidgets('lock screen on a normal phone: both links stay above the card', (
    t,
  ) async {
    await pumpAt(t, const Size(390, 844), await lockScreen(two));
    final card = t.getRect(find.byType(SponsorGrid));
    expect(
      t.getRect(find.byKey(const Key('lock-switch'))).bottom,
      lessThanOrEqualTo(card.top),
    );
  });

  testWidgets('Welcome: Mulai stays centred across and easy to press', (
    t,
  ) async {
    await pumpAt(t, const Size(390, 844), WelcomeScreen(sponsorLoader: two));
    final r = t.getRect(find.widgetWithText(FilledButton, 'Mulai'));
    expect(r.center.dx, closeTo(195, 1));
    expect(r.height, greaterThanOrEqualTo(48));
    expect(r.bottom, lessThan(844 * 0.85));
    // Two sponsors: one short row (caption plus tiles of at most 110 px).
    expect(t.getRect(find.byType(SponsorGrid)).height, lessThan(110));
  });

  testWidgets('Welcome has no "uji coba" notice', (t) async {
    await pumpAt(t, const Size(390, 844), WelcomeScreen(sponsorLoader: two));
    expect(find.textContaining('uji coba'), findsNothing);
  });

  testWidgets('lock screen uses the same page colour as the other pages', (
    t,
  ) async {
    await pumpAt(t, const Size(390, 844), await lockScreen(two));
    final scaffold = t.widget<Scaffold>(find.byKey(const Key('lock-screen')));
    expect(scaffold.backgroundColor, isNull); // theme page colour
    expect(find.textContaining('uji coba'), findsNothing);
  });

  testWidgets('phone: Mulai and the PIN pad sit in the lower half', (t) async {
    await pumpAt(t, const Size(390, 844), WelcomeScreen(sponsorLoader: two));
    expect(t.getCenter(find.text('Mulai')).dy, greaterThan(844 * 0.7));
    await pumpAt(t, const Size(390, 844), await lockScreen(two));
    expect(
      t.getCenter(find.byKey(const Key('pin-5'))).dy,
      greaterThan(844 * 0.45),
    );
  });
}
