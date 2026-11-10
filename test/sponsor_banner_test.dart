import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/widgets/sponsor_banner.dart';

import 'home_screen_test.dart' show pumpHome;
import 'support/fake_home.dart';

Future<void> pumpBanner(
  WidgetTester tester,
  List<Map<String, dynamic>> items, {
  void Function(Map<String, dynamic>)? onOpen,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SponsorBanner(
          items: items,
          onOpen: onOpen ?? (_) {},
          autoAdvance: const Duration(seconds: 3),
        ),
      ),
    ),
  );
  await tester.pump();
}

const complete = {
  'id': 'me',
  'name': 'Ahmad Ramadhan',
  'city': 'Semarang',
  'current_role': 'Analis',
};

void main() {
  group('SponsorBanner', () {
    testWidgets('shows nothing when there are no sponsors', (tester) async {
      await pumpBanner(tester, []);
      expect(find.byKey(const Key('sponsor-pages')), findsNothing);
      expect(find.text('Disponsori'), findsNothing);
    });

    testWidgets('one sponsor: label, no dots, tap opens it', (tester) async {
      Map<String, dynamic>? opened;
      await pumpBanner(tester, [sponsorMap(1)], onOpen: (s) => opened = s);
      expect(find.textContaining('Disponsori'), findsOneWidget);
      expect(find.byKey(const Key('sponsor-dots')), findsNothing);
      await tester.tap(find.byKey(const Key('sponsor-hero-0')));
      expect(opened?['id'], 'sp1');
    });

    testWidgets('card keeps the 16:5 shape', (tester) async {
      await pumpBanner(tester, [sponsorMap(1)]);
      final box = tester.getSize(find.byKey(const Key('sponsor-pages')));
      expect(box.width / box.height, closeTo(16 / 5, 0.01));
    });

    testWidgets('several sponsors: dots, auto slide and swipe', (tester) async {
      await pumpBanner(tester, [sponsorMap(1), sponsorMap(2), sponsorMap(3)]);
      expect(find.byKey(const Key('sponsor-dots')), findsOneWidget);
      expect(find.textContaining('Sponsor 1'), findsOneWidget);
      // Auto slide to the second one.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Sponsor 2'), findsOneWidget);
      // Swipe to the third.
      await tester.drag(
        find.byKey(const Key('sponsor-pages')),
        const Offset(-300, 0),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Sponsor 3'), findsOneWidget);
    });
  });

  group('Home', () {
    testWidgets('sponsor carousel sits right under the four tiles', (
      tester,
    ) async {
      await pumpHome(
        tester,
        api: FakeHomeApi(sponsors: [sponsorMap(1), sponsorMap(2)]),
        profile: complete,
      );
      final tiles = tester.getBottomLeft(
        find.byKey(const Key('tile-kontak-ikafe')),
      );
      final banner = tester.getTopLeft(find.byKey(const Key('sponsor-pages')));
      expect(banner.dy, greaterThan(tiles.dy));
      expect(banner.dy - tiles.dy, lessThan(40));
    });

    testWidgets('no sponsors or a failed load: nothing shown', (tester) async {
      await pumpHome(tester, api: FakeHomeApi(), profile: complete);
      expect(find.byKey(const Key('sponsor-pages')), findsNothing);
      await pumpHome(
        tester,
        api: FakeHomeApi(sponsorsError: Exception('x')),
        profile: complete,
      );
      expect(find.byKey(const Key('sponsor-pages')), findsNothing);
      expect(find.byKey(const Key('home-list')), findsOneWidget);
    });

    testWidgets('tap asks first, then opens the link; Batal opens nothing', (
      tester,
    ) async {
      final opened = <String?>[];
      await pumpHome(
        tester,
        api: FakeHomeApi(sponsors: [sponsorMap(1)]),
        profile: complete,
        openLink: (u) async {
          opened.add(u);
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('sponsor-hero-0')));
      await tester.pumpAndSettle();
      expect(find.text('Buka tautan sponsor ini?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      await tester.tap(find.byKey(const Key('sponsor-hero-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      expect(opened, ['https://sponsor1.example.com']);
    });

    testWidgets('a view is counted once per sponsor, a tap after Buka', (
      tester,
    ) async {
      final api = FakeHomeApi(sponsors: [sponsorMap(1), sponsorMap(2)]);
      await pumpHome(
        tester,
        api: api,
        profile: complete,
        openLink: (_) async => true,
        autoAdvance: const Duration(seconds: 3),
      );
      expect(api.sponsorEvents, ['view:sp1']);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.sponsorEvents, ['view:sp1', 'view:sp2']);
      // Around to the first one again: not counted a second time.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.sponsorEvents, ['view:sp1', 'view:sp2']);
      await tester.tap(find.byKey(const Key('sponsor-pages')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(api.sponsorEvents.where((e) => e.startsWith('tap')), isEmpty);
      await tester.tap(find.byKey(const Key('sponsor-pages')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      expect(api.sponsorEvents.where((e) => e.startsWith('tap')).length, 1);
    });

    testWidgets('a failing counter never breaks Home or the link', (
      tester,
    ) async {
      final api = FakeHomeApi(sponsors: [sponsorMap(1)])
        ..sponsorEventError = Exception('down');
      final opened = <String?>[];
      await pumpHome(
        tester,
        api: api,
        profile: complete,
        openLink: (u) async {
          opened.add(u);
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('sponsor-hero-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      expect(opened, ['https://sponsor1.example.com']);
    });

    testWidgets('hidden while the profile is still incomplete', (tester) async {
      await pumpHome(
        tester,
        api: FakeHomeApi(sponsors: [sponsorMap(1)]),
        profile: {'id': 'me', 'name': 'Ahmad Ramadhan'},
      );
      expect(find.byKey(const Key('sponsor-pages')), findsNothing);
    });
  });
}
