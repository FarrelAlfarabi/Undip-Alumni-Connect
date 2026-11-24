// Natasya, 24 Nov 2026: the journey asks for the email code too often. The
// live logs show it: a person enters a correct code, the sign in is made
// (verify and claim_alumni_profile both succeed, the session stays), but the
// app does not go in (Back, a reload, a closed tab) and the next visit shows
// the email box again, so a second code is sent for a person who is already
// signed in. A stored sign in now opens the app without a new code. Without
// a stored sign in, nothing changes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';

import 'account_test.dart' show appHome, phone, withPolicyBundle;
import 'real_login_test.dart' show FakeLoginApi, pumpVerify, settle;
import 'support/fake_lock.dart';

void main() {
  testWidgets('a stored sign in opens the app, no new code is sent', (
    tester,
  ) async {
    final api = FakeLoginApi()..resumeProfile = testProfile();
    await pumpVerify(tester, api);
    await settle(tester);
    expect(api.resumed, 1);
    expect(api.sent, isEmpty);
    expect(api.checked, isEmpty);
    expect(find.text('APP for ${testProfile()['name']}'), findsOneWidget);
  });

  testWidgets('no stored sign in: the email box, nothing resumed', (
    tester,
  ) async {
    final api = FakeLoginApi(session: false)..resumeProfile = testProfile();
    await pumpVerify(tester, api);
    await settle(tester);
    expect(api.resumed, 0);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });

  testWidgets('a stored sign in with no usable profile shows the email box', (
    tester,
  ) async {
    final api = FakeLoginApi()..resumeProfile = null;
    await pumpVerify(tester, api);
    await settle(tester);
    expect(api.resumed, 1);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(api.sent, isEmpty);
  });

  testWidgets('a failed resume (offline) shows the email box, sends nothing', (
    tester,
  ) async {
    final api = FakeLoginApi()..resumeError = Exception('network');
    await pumpVerify(tester, api);
    await settle(tester);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(api.sent, isEmpty);
    expect(api.signedOut, 0, reason: 'a network slip never ends the sign in');
  });

  testWidgets('a suspended account is not let in by a stored sign in', (
    tester,
  ) async {
    final api = FakeLoginApi()..resumeError = Exception('account_suspended');
    await pumpVerify(tester, api);
    await settle(tester);
    expect(find.text('APP for ${testProfile()['name']}'), findsNothing);
  });

  testWidgets('the email box still works after a resume that found nothing', (
    tester,
  ) async {
    final api = FakeLoginApi()..resumeProfile = null;
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
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'a@example.com',
    );
    await tester.tap(find.text('Kirim kode'));
    await settle(tester);
    expect(api.sent, ['a@example.com']);
  });
}
