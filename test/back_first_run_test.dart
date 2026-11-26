import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/nav/back_guard.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';

import 'support/fake_lock.dart';

/// First run: Welcome, verify, consent, PIN, app. Once the email is verified
/// the person is past Welcome, so Back on Consent or PIN must not walk back
/// to a stale Welcome screen. It asks "press again to exit" instead.

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') return rootBundle.load(key);
    final bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

int exits = 0;

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// A stand-in Welcome (the real one cannot take a fake email check), opening
/// the real VerificationScreen exactly as Welcome does: a plain push.
Future<void> startFirstRun(
  WidgetTester tester, {
  Map<String, dynamic>? profile,
}) async {
  BackGuard.reset();
  exits = 0;
  BackGuard.exitApp = () => exits++;
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(BackGuard.reset);
  final lock = makeLock(store: MemoryLockStore());
  Widget welcome() => Builder(
    builder: (context) => Scaffold(
      body: Column(
        children: [
          const Text('WELCOME'),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              AppRoute(
                builder: (_) => VerificationScreen(
                  lock: lock,
                  verifyEmail: (_) async =>
                      profile ?? testProfile(policyVersion: null),
                  homeBuilder: (p) => const Scaffold(body: Text('APP')),
                ),
              ),
            ),
            child: const Text('Mulai'),
          ),
        ],
      ),
    ),
  );
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: _DiskBundle(),
      child: MaterialApp(
        onGenerateInitialRoutes: (_) => [AppRoute(builder: (_) => welcome())],
        onGenerateRoute: (_) => AppRoute(builder: (_) => welcome()),
      ),
    ),
  );
  await tester.tap(find.text('Mulai'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), testEmail);
  await tester.tap(find.text('Verifikasi'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Back on Consent does not return to Welcome', (tester) async {
    await startFirstRun(tester);
    expect(find.byKey(const Key('consent-screen')), findsOneWidget);
    await back(tester);
    expect(find.text('WELCOME'), findsNothing);
    expect(find.byKey(const Key('consent-screen')), findsOneWidget);
    expect(find.byKey(const Key('exit-hint')), findsOneWidget);
    expect(exits, 0);
    await tester.pump(BackGuard.window);
  });

  testWidgets('Back on the PIN offer does not return to Welcome', (
    tester,
  ) async {
    // Consent already accepted: verification goes straight to the PIN offer.
    await startFirstRun(tester, profile: testProfile());
    expect(find.byKey(const Key('pin-setup')), findsOneWidget);
    await back(tester);
    expect(find.text('WELCOME'), findsNothing);
    expect(find.byKey(const Key('pin-setup')), findsOneWidget);
    expect(find.byKey(const Key('exit-hint')), findsOneWidget);
    expect(exits, 0);
    await tester.pump(BackGuard.window);
  });
}
