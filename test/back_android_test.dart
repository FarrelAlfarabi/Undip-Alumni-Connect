import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/nav/back_guard.dart';
import 'package:undip_alumni_connect/screens/home_shell.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';

import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

/// Android asks the app first on Back only while the app has told Android
/// "I handle Back" (setFrameworkHandlesBack). If that flag is false on any
/// screen, Android closes the app on the very first Back. These tests record
/// the flag, so every real configuration keeps it true.
final List<bool> handles = [];
int exits = 0;
final androidOnly = TargetPlatformVariant.only(TargetPlatform.android);

void recordPlatform(WidgetTester tester) {
  handles.clear();
  exits = 0;
  // The flag is only sent once the app is resumed (Android: see variant).
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        handles.add(call.arguments as bool);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

Widget app(Widget root) => MaterialApp(
  onGenerateInitialRoutes: (_) => [AppRoute(builder: (_) => root)],
  onGenerateRoute: (_) => AppRoute(builder: (_) => root),
);

HomeShell shell() => HomeShell(
  profile: const {'id': 'me', 'name': 'Ahmad', 'email': 'a@example.com'},
  chat: false,
  pages: fakePages(),
  homeApi: FakeHomeApi(announcements: [announcementMap(1)]),
  marketplaceRepository: MarketplaceRepository(FakeApi()),
);

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    BackGuard.reset();
    BackGuard.exitApp = () => exits++;
  });
  tearDown(BackGuard.reset);

  testWidgets('Welcome as first screen tells Android it handles Back', (
    tester,
  ) async {
    recordPlatform(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const WelcomeScreen()));
    await tester.pumpAndSettle();
    expect(handles, isNotEmpty);
    expect(handles.last, isTrue);
  }, variant: androidOnly);

  testWidgets('Home shell as first screen tells Android it handles Back', (
    tester,
  ) async {
    recordPlatform(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(shell()));
    await tester.pumpAndSettle();
    expect(handles, isNotEmpty);
    expect(handles.last, isTrue);
  }, variant: androidOnly);

  testWidgets('Home is the first route: Back walks tab by tab, then asks', (
    tester,
  ) async {
    recordPlatform(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(shell()));
    await tester.pumpAndSettle();
    Future<void> tab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    await tab('Members');
    await tab('Explore');
    await tab('Profile');
    await back(tester); // Explore
    expect(find.text('Halo, Ahmad'), findsNothing);
    await back(tester); // Members
    await back(tester); // Home
    expect(find.text('Halo, Ahmad'), findsOneWidget);
    expect(exits, 0);
    await back(tester); // hint only
    expect(exits, 0);
    expect(find.byKey(const Key('exit-hint')), findsOneWidget);
    expect(handles.last, isTrue);
    await tester.pump(BackGuard.window);
  }, variant: androidOnly);

  testWidgets('a screen opened over Home: Back closes it, never the app', (
    tester,
  ) async {
    recordPlatform(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(shell()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-kontak-ikafe')));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Ahmad'), findsNothing);
    await back(tester);
    expect(find.text('Halo, Ahmad'), findsOneWidget);
    expect(exits, 0);
    expect(find.byKey(const Key('exit-hint')), findsNothing);
    expect(handles.last, isTrue);
  }, variant: androidOnly);
}
