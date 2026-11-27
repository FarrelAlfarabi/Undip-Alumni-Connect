import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';
import 'package:undip_alumni_connect/widgets/banner_carousel.dart';
import 'package:undip_alumni_connect/widgets/sponsor_banner.dart';
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
  const sizes = {
    'phone': Size(390, 844),
    'small phone': Size(360, 640),
    'desktop': Size(1440, 900),
  };
  for (final e in sizes.entries) {
    testWidgets('Welcome shows sponsors at the bottom, ${e.key}', (t) async {
      await pumpAt(t, e.value, WelcomeScreen(sponsorLoader: two));
      expect(find.byType(SponsorBanner), findsOneWidget);
      final banner = t.getRect(find.byType(BannerCarousel));
      if (e.value.width < 1000) {
        expect(banner.bottom, greaterThan(e.value.height * 0.6));
      } else {
        // Wide screen: inside the centred card, at its bottom.
        expect(
          t.getRect(find.byKey(const Key('auth-card'))).bottom,
          greaterThanOrEqualTo(banner.bottom),
        );
      }
      expect(banner.width, lessThanOrEqualTo(kSponsorSlotMaxWidth));
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
      expect(find.byType(SponsorBanner), findsOneWidget);
      final banner = t.getRect(find.byType(BannerCarousel));
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
    expect(find.byType(SponsorBanner), findsNothing);
    await pumpAt(t, const Size(390, 844), WelcomeScreen(sponsorLoader: boom));
    expect(find.byType(SponsorBanner), findsNothing);
    expect(find.text('Mulai'), findsOneWidget);
    await pumpAt(t, const Size(390, 844), await lockScreen(boom));
    expect(find.byType(SponsorBanner), findsNothing);
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
    expect(events.where((e) => e.startsWith('view:')).length, 1);
    await t.tap(find.byType(SponsorBanner));
    await t.pumpAndSettle();
    await t.tap(find.text('Batal'));
    await t.pumpAndSettle();
    expect(events.any((e) => e.startsWith('tap:')), isFalse);
    expect(opened, isEmpty);
    await t.tap(find.byType(SponsorBanner));
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
    final card = t.getRect(find.byType(BannerCarousel));
    expect(
      t.getRect(find.byKey(const Key('lock-switch'))).bottom,
      lessThanOrEqualTo(card.top),
    );
  });
}
