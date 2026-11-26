import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/app_entry.dart';
import 'package:undip_alumni_connect/lock/lock_screen.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/lock/pin_setup_screen.dart';
import 'package:undip_alumni_connect/screens/returning_screen.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';
import 'package:undip_alumni_connect/theme.dart';
import 'package:undip_alumni_connect/widgets/auth_frame.dart';

import 'account_test.dart' show appHome;
import 'real_login_test.dart' show FakeLoginApi;
import 'support/fake_lock.dart';

/// Web stage 1: login and start screens on wide screens, and telling a
/// first-time visitor from a returning one in a browser.
const _widths = [390.0, 768.0, 1280.0];

void _size(WidgetTester t, double w, [double h = 900]) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _pump(WidgetTester t, double w, Widget home) async {
  _size(t, w);
  await t.pumpWidget(MaterialApp(theme: AppTheme.light(), home: home));
  await t.pump();
  await t.pump();
}

Future<void> _pumpEntry(
  WidgetTester t,
  LockService lock, {
  required bool web,
  FakeLoginApi? api,
  ProfileFetcher? fetch,
  double width = 1280,
}) async {
  _size(t, width);
  await t.pumpWidget(
    MaterialApp(
      home: AppEntry(
        lock: lock,
        web: web,
        loginApi: api ?? FakeLoginApi(),
        fetchProfile: fetch ?? (id) async => testProfile(),
        homeBuilder: appHome,
      ),
    ),
  );
  await t.pump();
  await t.pump();
  await t.pump();
}

void main() {
  group('start screens at phone, tablet and desktop width', () {
    Future<Map<String, Widget>> screens() async {
      final lock = await makeRememberedLock();
      final user = (await lock.load())!;
      return {
        'Welcome': const WelcomeScreen(),
        'Returning': ReturningScreen(name: 'Ahmad', onNotYou: () async {}),
        'Lock': LockScreen(
          lock: lock,
          user: user,
          autoBiometric: false,
          onUnlocked: () async {},
          onSwitchAccount: () async {},
          onForgotPin: () async {},
          onLockedOut: () async {},
          onContinue: () async {},
        ),
        'PIN setup': PinSetupScreen(lock: lock, onDone: (_) async {}),
      };
    }

    for (final name in ['Welcome', 'Returning', 'Lock', 'PIN setup']) {
      for (final w in _widths) {
        testWidgets('$name at ${w.toInt()}', (t) async {
          await _pump(t, w, (await screens())[name]!);
          expect(t.takeException(), isNull);
          final card = find.byKey(const Key('auth-card'));
          if (w < 600) {
            // Phone layout stays as it was: no card around the content.
            expect(card, findsNothing);
          } else {
            expect(card, findsOneWidget);
            final box = t.getRect(card);
            expect(box.width, lessThanOrEqualTo(520));
            // Centred on the page.
            expect((box.center.dx - w / 2).abs(), lessThan(1));
          }
        });
      }
    }

    for (final w in _widths) {
      testWidgets('email step at ${w.toInt()} keeps a narrow card', (t) async {
        await _pump(
          t,
          w,
          VerificationScreen(
            loginApi: FakeLoginApi(),
            lock: makeLock(enabled: false),
            homeBuilder: appHome,
          ),
        );
        expect(t.takeException(), isNull);
        final field = t.getRect(find.byKey(const Key('login-email')));
        expect(field.width, lessThanOrEqualTo(440));
        expect((field.center.dx - w / 2).abs(), lessThan(1));
      });
    }

    testWidgets('AuthFrame gives the phone the full width', (t) async {
      await _pump(
        t,
        390,
        const Scaffold(
          body: AuthFrame(
            child: SizedBox(key: Key('c'), width: double.infinity, height: 10),
          ),
        ),
      );
      expect(t.getSize(find.byKey(const Key('c'))).width, greaterThan(300));
    });
  });

  group('first-time and returning visitors on web', () {
    testWidgets('nothing remembered shows the first-time Welcome', (t) async {
      await _pumpEntry(t, makeLock(), web: true);
      expect(find.text('Mulai'), findsOneWidget);
      expect(find.byKey(const Key('returning-screen')), findsNothing);
    });

    testWidgets('signed in with a PIN: the PIN screen, no email code', (
      t,
    ) async {
      final api = FakeLoginApi();
      await _pumpEntry(t, await makeRememberedLock(), web: true, api: api);
      expect(find.byKey(const Key('lock-screen')), findsOneWidget);
      await enterPin(t, testPin);
      await t.pump();
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      expect(api.sent, isEmpty);
    });

    testWidgets('signed in without a PIN: make a PIN, no email code', (
      t,
    ) async {
      final api = FakeLoginApi();
      final lock = await makeRememberedLock(withPin: false);
      await _pumpEntry(t, lock, web: true, api: api);
      await t.pump();
      // No way to skip: the PIN is what lets "Keluar" come back without a code.
      expect(find.byKey(const Key('pin-setup')), findsOneWidget);
      expect(find.byKey(const Key('pin-skip')), findsNothing);
      expect(find.text('Verifikasi Status Alumni'), findsNothing);
      await enterPin(t, testPin);
      await enterPin(t, testPin);
      await t.pump();
      await t.pump();
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      expect(await lock.hasPin(), isTrue);
      expect(api.sent, isEmpty);
    });

    testWidgets(
      'remembered person is not the signed in one: open the signed in '
      'person and remember them',
      (t) async {
        // The browser remembered p1, but the stored sign in belongs to p2. The
        // app used to open p1, so every save hit a row the sign in cannot edit.
        final api = FakeLoginApi()
          ..resumeProfile = {
            ...testProfile(),
            'id': 'p2',
            'name': 'Budi Santoso',
          };
        final lock = await makeRememberedLock(withPin: false);
        await _pumpEntry(
          t,
          lock,
          web: true,
          api: api,
          fetch: (id) async => {
            ...testProfile(),
            'id': id,
            'name': id == 'p2' ? 'Budi Santoso' : 'Ahmad Ramadhan',
          },
        );
        await t.pump();
        await enterPin(t, testPin);
        await enterPin(t, testPin);
        await t.pump();
        await t.pump();
        expect(find.text('APP for Budi Santoso'), findsOneWidget);
        expect((await lock.load())!.profileId, 'p2');
      },
    );

    testWidgets('phone without a PIN still asks to verify (unchanged)', (
      t,
    ) async {
      final lock = await makeRememberedLock(withPin: false);
      await _pumpEntry(t, lock, web: false, width: 390);
      expect(find.byKey(const Key('lock-continue')), findsOneWidget);
      expect(find.text('APP for Ahmad Ramadhan'), findsNothing);
    });

    testWidgets('no PIN and a failed profile load: Lanjut tries again', (
      t,
    ) async {
      var fail = true;
      final lock = await makeRememberedLock(withPin: false);
      await _pumpEntry(
        t,
        lock,
        web: true,
        fetch: (id) async {
          if (fail) throw Exception('offline');
          return testProfile();
        },
      );
      await t.pump();
      expect(find.text('APP for Ahmad Ramadhan'), findsNothing);
      expect(find.byKey(const Key('lock-continue')), findsOneWidget);
      // Still remembered: a network error forgets nobody.
      expect(await lock.load(), isNotNull);
      fail = false;
      await t.tap(find.byKey(const Key('lock-continue')));
      await t.pump();
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('pin-setup')), findsOneWidget);
    });

    testWidgets('expired sign in shows the returning screen, not Welcome', (
      t,
    ) async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await _pumpEntry(t, lock, web: true, api: FakeLoginApi(session: false));
      await enterPin(t, testPin);
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('returning-screen')), findsOneWidget);
      expect(find.text('Selamat datang kembali, Ahmad'), findsOneWidget);
      expect(find.text('Mulai'), findsNothing);
      // First name only: no full name, email or id is kept for the marker.
      expect(await lock.returningName(), 'Ahmad');
      expect(await lock.load(), isNull);
      expect(store.data.values.join(' '), isNot(contains('Ramadhan')));
      expect(store.data.values.join(' '), isNot(contains('@')));
    });

    testWidgets('expired sign in without a PIN also shows returning', (
      t,
    ) async {
      final lock = await makeRememberedLock(withPin: false);
      await _pumpEntry(t, lock, web: true, api: FakeLoginApi(session: false));
      await t.pump();
      expect(find.byKey(const Key('returning-screen')), findsOneWidget);
      expect(find.text('APP for Ahmad Ramadhan'), findsNothing);
    });

    testWidgets('the marker alone never opens the app', (t) async {
      final lock = makeLock();
      await lock.markReturning('Ahmad Ramadhan');
      var fetched = 0;
      await _pumpEntry(
        t,
        lock,
        web: true,
        fetch: (id) async {
          fetched++;
          return testProfile();
        },
      );
      expect(find.byKey(const Key('returning-screen')), findsOneWidget);
      expect(find.text('APP for Ahmad Ramadhan'), findsNothing);
      expect(fetched, 0);
      // "Masuk lagi" leads to the email code step.
      await t.tap(find.byKey(const Key('returning-continue')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
    });

    testWidgets('"Bukan kamu?" clears the marker and shows Welcome', (t) async {
      final lock = makeLock();
      await lock.markReturning('Ahmad Ramadhan');
      await _pumpEntry(t, lock, web: true);
      await t.tap(find.byKey(const Key('returning-not-you')));
      await t.pump();
      await t.pump();
      expect(find.text('Mulai'), findsOneWidget);
      expect(await lock.returningName(), isNull);
    });

    testWidgets('a phone ignores the marker', (t) async {
      final lock = makeLock();
      await lock.markReturning('Ahmad Ramadhan');
      await _pumpEntry(t, lock, web: false, width: 390);
      expect(find.text('Mulai'), findsOneWidget);
      expect(find.byKey(const Key('returning-screen')), findsNothing);
    });

    test('sign out, wipe and a new sign in all clear the marker', () async {
      final lock = makeLock();
      await lock.markReturning('Ahmad Ramadhan');
      await lock.signOut();
      expect(await lock.returningName(), isNull);

      await lock.markReturning('Ahmad Ramadhan');
      await lock.clear();
      expect(await lock.returningName(), isNull);

      await lock.markReturning('Ahmad Ramadhan');
      await lock.remember(
        profileId: 'p1',
        displayName: 'Ahmad Ramadhan',
        email: testEmail,
      );
      expect(await lock.returningName(), isNull);
    });

    test('a blank name leaves no marker', () async {
      final lock = makeLock();
      await lock.markReturning('   ');
      expect(await lock.returningName(), isNull);
    });
  });

  group('Keluar on web comes back with the PIN, not a new email code', () {
    Future<void> pumpLeave(
      WidgetTester t,
      LockService lock,
      FakeLoginApi api, {
      required bool web,
    }) async {
      _size(t, 1280);
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => leaveApp(
                  context,
                  const Text('VERIFY'),
                  lock: lock,
                  login: api,
                  web: web,
                  entryBuilder: () => AppEntry(
                    lock: lock,
                    web: web,
                    loginApi: api,
                    fetchProfile: (id) async => testProfile(),
                    homeBuilder: appHome,
                  ),
                ),
                child: const Text('KELUAR'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('KELUAR'));
      await t.pumpAndSettle();
    }

    testWidgets('with a PIN: PIN screen, sign in kept, PIN opens the app', (
      t,
    ) async {
      final lock = await makeRememberedLock();
      lock.sessionActive = true;
      final api = FakeLoginApi();
      await pumpLeave(t, lock, api, web: true);
      expect(find.byKey(const Key('lock-screen')), findsOneWidget);
      expect(find.text('VERIFY'), findsNothing);
      expect(api.signedOut, 0);
      expect(lock.sessionActive, isFalse);
      expect(await lock.load(), isNotNull);
      await enterPin(t, testPin);
      await t.pump();
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      expect(api.sent, isEmpty);
    });

    testWidgets('phone: Keluar still signs out fully (unchanged)', (t) async {
      final lock = await makeRememberedLock();
      final api = FakeLoginApi();
      await pumpLeave(t, lock, api, web: false);
      expect(find.text('VERIFY'), findsOneWidget);
      expect(api.signedOut, 1);
      expect(await lock.load(), isNull);
    });

    testWidgets('web without a PIN: full sign out', (t) async {
      final noPin = await makeRememberedLock(withPin: false);
      final api = FakeLoginApi();
      await pumpLeave(t, noPin, api, web: true);
      expect(find.text('VERIFY'), findsOneWidget);
      expect(api.signedOut, 1);
    });

    testWidgets('web with an ended sign in: full sign out', (t) async {
      final expired = await makeRememberedLock();
      final api2 = FakeLoginApi(session: false);
      await pumpLeave(t, expired, api2, web: true);
      expect(find.text('VERIFY'), findsOneWidget);
      expect(await expired.load(), isNull);
    });

    testWidgets('"Bukan kamu? Ganti akun" really signs out', (t) async {
      final lock = await makeRememberedLock();
      final api = FakeLoginApi();
      await _pumpEntry(t, lock, web: true, api: api);
      await t.ensureVisible(find.byKey(const Key('lock-switch')));
      await t.tap(find.byKey(const Key('lock-switch')));
      await t.pump();
      await t.tap(find.byKey(const Key('lock-confirm-yes')));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Mulai'), findsOneWidget);
      expect(api.signedOut, 1);
      expect(await lock.hasPin(), isFalse);
    });

    test('the Profile sign out button uses it', () {
      final src = File('lib/screens/profile_detail_screen.dart')
          .readAsStringSync();
      expect(src, contains(RegExp(r'onSignOut: \(\) =>\s+leaveApp\(')));
    });
  });

  group('web page shell', () {
    final html = File('web/index.html').readAsStringSync();

    test('the installed web app is not locked to portrait', () {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
      expect(manifest.containsKey('orientation'), isFalse);
    });

    test('the zoom guard blocks zoom only on phones and tablets', () {
      final js = File('web/viewport_guard.js').readAsStringSync();
      expect(js, contains('iPhone'));
      expect(js, contains('maxTouchPoints'));
      // On a computer the script stops before blocking anything, so browser
      // zoom keeps working for people who need bigger text.
      expect(js.indexOf('if (!isPhoneOrTablet) {'), isNonNegative);
      expect(
        js.indexOf('if (!isPhoneOrTablet) {'),
        lessThan(js.indexOf('gesturestart')),
      );
    });

    test('a start screen paints before Flutter has loaded', () {
      expect(html, contains('id="splash"'));
      final splash = html.indexOf('src="splash.js"');
      expect(splash, isNonNegative);
      expect(splash, lessThan(html.indexOf('src="flutter_bootstrap.js"')));
      final js = File('web/splash.js').readAsStringSync();
      expect(js, contains('flutter-first-frame'));
      expect(js, isNot(contains('eval(')));
      // No inline script: the Content-Security-Policy only allows files.
      expect(RegExp(r'<script(?![^>]*\ssrc=)[^>]*>').hasMatch(html), isFalse);
    });

    test('the app code starts downloading at once', () {
      expect(
        RegExp(r'<link[^>]*rel="preload"[^>]*href="main\.dart\.js"[^>]*>')
            .hasMatch(html),
        isTrue,
      );
      expect(
        RegExp(
          r'<link[^>]*rel="preconnect"[^>]*href="https://www\.gstatic\.com"',
        ).hasMatch(html),
        isTrue,
      );
    });
  });
}
