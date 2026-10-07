import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/block_list.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/home_shell.dart';

import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

/// Directory and Market sit in an IndexedStack, so they used to fetch once and
/// show that forever: new people and products never appeared, and a person you
/// just blocked stayed on screen. Coming back to a tab after the refresh window
/// (these tests use none), or changing the block list, now rebuilds it (which
/// refetches). The first visit builds it; coming back inside the window keeps
/// it, so tab switches are not a spinner every time.
const profile = {
  'id': 'me',
  'name': 'Ahmad Ramadhan',
  'email': 'a@example.com',
};

Future<void> pump(
  WidgetTester tester, {
  required List<int> directoryBuilds,
  required List<int> marketBuilds,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  BlockList.shared.blocked.value = const {};
  await tester.pumpWidget(
    MaterialApp(
      home: HomeShell(
        profile: profile,
        chat: false,
        refreshAfter: Duration.zero,
        pages: fakePages(
          directoryBuilds: directoryBuilds,
          marketBuilds: marketBuilds,
        ),
        homeApi: FakeHomeApi(announcements: [announcementMap(1)]),
        marketplaceRepository: MarketplaceRepository(FakeApi()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening the Directory tab rebuilds it, so it refetches', (
    tester,
  ) async {
    final dir = <int>[];
    await pump(tester, directoryBuilds: dir, marketBuilds: <int>[]);
    final before = dir.length;
    await tapNav(tester, 'Directory');
    expect(dir.length, greaterThan(before));
  });

  testWidgets('opening the Market tab rebuilds it, so it refetches', (
    tester,
  ) async {
    final market = <int>[];
    await pump(tester, directoryBuilds: <int>[], marketBuilds: market);
    final before = market.length;
    await tapNav(tester, 'Market');
    expect(market.length, greaterThan(before));
  });

  testWidgets('coming back soon does not refetch, only after a while', (
    tester,
  ) async {
    final dir = <int>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    BlockList.shared.blocked.value = const {};
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          profile: profile,
          chat: false,
          pages: fakePages(directoryBuilds: dir, marketBuilds: <int>[]),
          homeApi: FakeHomeApi(announcements: [announcementMap(1)]),
          marketplaceRepository: MarketplaceRepository(FakeApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapNav(tester, 'Directory');
    await tapNav(tester, 'Home');
    await tapNav(tester, 'Directory');
    expect(dir.length, 1); // default window is minutes, not milliseconds
  });

  testWidgets('staying on the same tab does not rebuild it', (tester) async {
    final dir = <int>[];
    await pump(tester, directoryBuilds: dir, marketBuilds: <int>[]);
    await tapNav(tester, 'Directory');
    final after = dir.length;
    await tapNav(tester, 'Directory');
    expect(dir.length, after);
  });

  testWidgets('blocking someone rebuilds Directory and Market', (tester) async {
    final dir = <int>[];
    final market = <int>[];
    await pump(tester, directoryBuilds: dir, marketBuilds: market);
    await tapNav(tester, 'Directory');
    await tapNav(tester, 'Market');
    await tapNav(tester, 'Home');
    final d = dir.length;
    final m = market.length;
    BlockList.shared.blocked.value = {'person-1'};
    await tester.pumpAndSettle();
    expect(dir.length, greaterThan(d));
    expect(market.length, greaterThan(m));
  });

  testWidgets('a block list that did not change does not rebuild anything', (
    tester,
  ) async {
    final dir = <int>[];
    await pump(tester, directoryBuilds: dir, marketBuilds: <int>[]);
    BlockList.shared.blocked.value = {'person-1'};
    await tester.pumpAndSettle();
    final d = dir.length;
    BlockList.shared.blocked.value = {'person-1'}; // same people, new set
    await tester.pumpAndSettle();
    expect(dir.length, d);
  });
}
