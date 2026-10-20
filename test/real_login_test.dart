import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/auth/login_api.dart';
import 'package:undip_alumni_connect/lock/app_entry.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';

import 'account_test.dart' show appHome, phone, withPolicyBundle;
import 'support/fake_lock.dart';

class FakeLoginApi implements LoginApi {
  FakeLoginApi({this.known = true, this.session = true});

  bool known;
  bool session;
  Object? verifyError;
  Map<String, dynamic>? profile = testProfile();
  final sent = <String>[];
  final checked = <String>[];
  var signedOut = 0;

  @override
  Future<bool> emailKnown(String email) async => known;

  @override
  Future<void> sendCode(String email) async => sent.add(email);

  @override
  Future<Map<String, dynamic>?> verifyCode(String email, String code) async {
    checked.add(code);
    if (verifyError != null) throw verifyError!;
    return profile;
  }

  @override
  bool get hasSession => session;

  @override
  Future<void> signOut() async => signedOut++;
}

Future<void> pumpVerify(WidgetTester tester, FakeLoginApi api) async {
  phone(tester);
  await tester.pumpWidget(
    withPolicyBundle(
      MaterialApp(
        home: VerificationScreen(
          loginApi: api,
          lock: makeLock(enabled: false),
          homeBuilder: appHome,
        ),
      ),
    ),
  );
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('real login is off unless the build turns it on', () {
    expect(kRealLogin, isFalse);
  });

  group('code login screen', () {
    testWidgets('email first, then a code box, then the app', (tester) async {
      final api = FakeLoginApi();
      await pumpVerify(tester, api);
      expect(find.byKey(const Key('login-code')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('login-email')),
        ' Ahmad.Ramadhan@Example.com ',
      );
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      expect(api.sent, ['ahmad.ramadhan@example.com']);
      expect(find.byKey(const Key('code-sent-note')), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsNothing);

      await tester.enterText(find.byKey(const Key('login-code')), '123456');
      await settle(tester); // the sixth digit checks the code by itself
      expect(api.checked, ['123456']);
      expect(find.text('APP for ${testProfile()['name']}'), findsOneWidget);
    });

    testWidgets('an unknown email looks the same but gets no code', (
      tester,
    ) async {
      final api = FakeLoginApi(known: false);
      await pumpVerify(tester, api);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'nobody@example.com',
      );
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      expect(api.sent, isEmpty);
      expect(find.byKey(const Key('login-code')), findsOneWidget);
      expect(find.text('Data Tidak Ditemukan'), findsNothing);
      expect(find.byKey(const Key('login-help')), findsOneWidget);
    });

    testWidgets('the code must be 6 digits before it is checked', (
      tester,
    ) async {
      final api = FakeLoginApi();
      await pumpVerify(tester, api);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'a@example.com',
      );
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('login-code')), '12ab');
      await tester.tap(find.text('Verifikasi kode'));
      await settle(tester);
      expect(find.text('Masukkan kode 6 digit'), findsOneWidget);
      expect(api.checked, isEmpty);
    });

    testWidgets('a wrong or expired code stays on the code step', (
      tester,
    ) async {
      final api = FakeLoginApi()..verifyError = Exception('otp_expired');
      await pumpVerify(tester, api);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'a@example.com',
      );
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('login-code')), '000000');
      await settle(tester);
      expect(
        find.textContaining('salah atau sudah kedaluwarsa'),
        findsOneWidget,
      );
      expect(find.text('Terjadi Kesalahan'), findsNothing);
      expect(find.byKey(const Key('login-code')), findsOneWidget);
      // Can try again right away.
      api.verifyError = null;
      await tester.enterText(find.byKey(const Key('login-code')), '123456');
      await settle(tester);
      expect(api.checked, ['000000', '123456']);
    });

    testWidgets('resend waits 30 seconds, then sends a new code', (
      tester,
    ) async {
      final api = FakeLoginApi();
      await pumpVerify(tester, api);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'a@example.com',
      );
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      expect(find.text('Kirim ulang kode dalam 30 dtk'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Kirim ulang kode'), findsOneWidget);
      await tester.tap(find.byKey(const Key('login-resend')));
      await settle(tester);
      expect(api.sent.length, 2);
      expect(find.text('Kirim ulang kode dalam 30 dtk'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('a person who is not verified is not let in', (tester) async {
      final api = FakeLoginApi()..profile = null;
      await pumpVerify(tester, api);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'a@example.com',
      );
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('login-code')), '123456');
      await settle(tester);
      expect(find.text('Data Tidak Ditemukan'), findsOneWidget);
    });

    testWidgets('"Use a different email" goes back to the email box', (
      tester,
    ) async {
      final api = FakeLoginApi();
      await pumpVerify(tester, api);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'a@example.com',
      );
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('login-change-email')));
      await tester.pump();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
    });
  });

  group('app start with real login', () {
    testWidgets('a remembered PIN is not enough without a stored sign in', (
      tester,
    ) async {
      phone(tester);
      final lock = await makeRememberedLock();
      await tester.pumpWidget(
        MaterialApp(
          home: AppEntry(
            lock: lock,
            loginApi: FakeLoginApi(session: false),
            fetchProfile: (id) async => testProfile(),
            homeBuilder: appHome,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await enterPin(tester, testPin);
      await tester.pump();
      expect(find.text(kSessionExpiredNotice), findsOneWidget);
      expect(find.text('Mulai'), findsOneWidget);
      expect(await lock.load(), isNull);
    });

    testWidgets('with a stored sign in the PIN opens the app', (tester) async {
      phone(tester);
      final lock = await makeRememberedLock();
      await tester.pumpWidget(
        MaterialApp(
          home: AppEntry(
            lock: lock,
            loginApi: FakeLoginApi(),
            fetchProfile: (id) async => testProfile(),
            homeBuilder: appHome,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await enterPin(tester, testPin);
      await tester.pump();
      expect(find.text('APP for ${testProfile()['name']}'), findsOneWidget);
    });
  });
}
