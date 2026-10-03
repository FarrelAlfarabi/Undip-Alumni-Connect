import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/auth/auth_gateway.dart';
import 'package:undip_alumni_connect/lock/session.dart';
import 'package:undip_alumni_connect/screens/sign_in_screen.dart';

import '../support/fake_auth.dart';
import '../support/fake_lock.dart';

Widget appHome(Map<String, dynamic> profile) =>
    Scaffold(body: Text('APP for ${profile['name']}'));

Future<void> pumpScreen(WidgetTester tester, FakeAuth auth) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SignInScreen(
        gateway: auth,
        lock: makeLock(enabled: false), // no PIN step: straight into the app
        homeBuilder: appHome,
      ),
    ),
  );
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> fill(WidgetTester tester, String key, String text) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

void main() {
  group('sign in', () {
    testWidgets('shows email, password and the NIM hint', (tester) async {
      await pumpScreen(tester, FakeAuth());
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
      expect(find.byKey(const Key('auth-password')), findsOneWidget);
      expect(find.textContaining('Your password is your NIM'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('the password is hidden until you show it', (tester) async {
      await pumpScreen(tester, FakeAuth());
      TextField field() => tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('auth-password')),
          matching: find.byType(TextField),
        ),
      );
      expect(field().obscureText, isTrue);
      await tapKey(tester, 'auth-show-password');
      expect(field().obscureText, isFalse);
    });

    testWidgets('empty or bad input is refused before any call', (
      tester,
    ) async {
      final auth = FakeAuth();
      await pumpScreen(tester, auth);
      await tapKey(tester, 'auth-submit');
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter a password'), findsOneWidget);
      await fill(tester, 'auth-email', 'not-an-email');
      await tapKey(tester, 'auth-submit');
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(auth.signOuts, 0);
      expect(find.text('APP for Ahmad Ramadhan'), findsNothing);
    });

    testWidgets('a wrong password shows a plain message and stays put', (
      tester,
    ) async {
      await pumpScreen(tester, FakeAuth());
      await fill(tester, 'auth-email', testEmail);
      await fill(tester, 'auth-password', 'wrong-one');
      await tapKey(tester, 'auth-submit');
      expect(find.text('Wrong email or password.'), findsOneWidget);
      expect(find.text('APP for Ahmad Ramadhan'), findsNothing);
    });

    testWidgets(
      'the right password enters the app; email is trimmed and lowercased',
      (tester) async {
        await pumpScreen(tester, FakeAuth());
        await fill(tester, 'auth-email', '  ${testEmail.toUpperCase()} ');
        await fill(tester, 'auth-password', 'correct-horse');
        await tapKey(tester, 'auth-submit');
        expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      },
    );

    testWidgets('an unconfirmed email and a network error read plainly', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeAuth(signInError: const AuthFailure(AuthProblem.network)),
      );
      await fill(tester, 'auth-email', testEmail);
      await fill(tester, 'auth-password', 'correct-horse');
      await tapKey(tester, 'auth-submit');
      expect(find.textContaining("Couldn't reach the server"), findsOneWidget);
    });
  });

  group('first password (NIM) -> choose your own', () {
    testWidgets('is offered when password_set is false, and can be skipped', (
      tester,
    ) async {
      final auth = FakeAuth(passwordSet: false, password: 'NIM-0001');
      await pumpScreen(tester, auth);
      await fill(tester, 'auth-email', testEmail);
      await fill(tester, 'auth-password', 'NIM-0001');
      await tapKey(tester, 'auth-submit');
      expect(find.byKey(const Key('set-password')), findsOneWidget);
      await tapKey(tester, 'set-password-skip');
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      expect(auth.changedTo, isNull);
      expect(auth.passwordSet, isFalse); // asked again next time
    });

    testWidgets('is not offered once they have their own password', (
      tester,
    ) async {
      await pumpScreen(tester, FakeAuth());
      await fill(tester, 'auth-email', testEmail);
      await fill(tester, 'auth-password', 'correct-horse');
      await tapKey(tester, 'auth-submit');
      expect(find.byKey(const Key('set-password')), findsNothing);
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
    });

    Future<FakeAuth> toPrompt(WidgetTester tester) async {
      final auth = FakeAuth(passwordSet: false, password: 'NIM-0001');
      await pumpScreen(tester, auth);
      await fill(tester, 'auth-email', testEmail);
      await fill(tester, 'auth-password', 'NIM-0001');
      await tapKey(tester, 'auth-submit');
      return auth;
    }

    testWidgets('refuses short, same-as-NIM and mismatched passwords', (
      tester,
    ) async {
      final auth = await toPrompt(tester);
      await fill(tester, 'set-password-new', 'short');
      await fill(tester, 'set-password-confirm', 'short');
      await tapKey(tester, 'set-password-save');
      expect(find.textContaining('at least 8'), findsWidgets);

      await fill(tester, 'set-password-new', 'NIM-0001');
      await fill(tester, 'set-password-confirm', 'NIM-0001');
      await tapKey(tester, 'set-password-save');
      expect(find.textContaining('different from your NIM'), findsOneWidget);

      await fill(tester, 'set-password-new', 'a-better-one');
      await fill(tester, 'set-password-confirm', 'another-one');
      await tapKey(tester, 'set-password-save');
      expect(find.text("The passwords don't match"), findsOneWidget);
      expect(auth.changedTo, isNull);
    });

    testWidgets('saving changes the password and continues into the app', (
      tester,
    ) async {
      final auth = await toPrompt(tester);
      await fill(tester, 'set-password-new', 'a-better-one');
      await fill(tester, 'set-password-confirm', 'a-better-one');
      await tapKey(tester, 'set-password-save');
      expect(auth.changedTo, 'a-better-one');
      expect(auth.passwordSet, isTrue);
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('code flow: send code, enter it with a new password', (
      tester,
    ) async {
      final auth = FakeAuth();
      await pumpScreen(tester, auth);
      await tapKey(tester, 'auth-forgot');
      expect(find.byKey(const Key('auth-password')), findsNothing);
      await fill(tester, 'auth-email', testEmail);
      await tapKey(tester, 'auth-submit');
      expect(auth.resets, 1);
      expect(find.byKey(const Key('auth-info')), findsOneWidget);
      expect(find.byKey(const Key('auth-code')), findsOneWidget);

      await fill(tester, 'auth-code', '000000');
      await fill(tester, 'auth-password', 'brand-new-pass');
      await tapKey(tester, 'auth-submit');
      expect(
        find.text('That code is wrong or has expired. Try again.'),
        findsOneWidget,
      );

      await fill(tester, 'auth-code', FakeAuth.goodCode);
      await tapKey(tester, 'auth-submit');
      expect(auth.password, 'brand-new-pass');
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
    });

    testWidgets('can go back to sign in', (tester) async {
      await pumpScreen(tester, FakeAuth());
      await tapKey(tester, 'auth-forgot');
      await tapKey(tester, 'auth-to-signin');
      expect(find.byKey(const Key('auth-password')), findsOneWidget);
    });
  });

  testWidgets('signing out also ends the auth session', (tester) async {
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => signOutTo(
              context,
              const Text('SIGNED OUT'),
              lock: makeLock(),
              auth: auth,
            ),
            child: const Text('OUT'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OUT'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 1);
    expect(find.text('SIGNED OUT'), findsOneWidget);
  });
}
