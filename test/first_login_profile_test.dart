import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/session.dart';
import 'package:undip_alumni_connect/screens/default_contact_screen.dart';
import 'package:undip_alumni_connect/screens/first_login_profile_screen.dart';
import 'package:undip_alumni_connect/screens/profile_setup_screen.dart';

import 'support/fake_lock.dart';

Widget appHome(Map<String, dynamic> p) =>
    Scaffold(body: Text('APP for ${p['name']}'));

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> enter(WidgetTester tester, Map<String, dynamic> profile) async {
  phone(tester);
  final lock = makeLock();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () =>
                enterApp(ctx, profile, lock: lock, homeBuilder: appHome),
            child: const Text('ENTER'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ENTER'));
  await tester.pumpAndSettle();
}

void main() {
  group('first login: optional profile step', () {
    testWidgets('first login shows the step before the app', (tester) async {
      await enter(tester, {...testProfile(), kFirstLoginKey: true});
      expect(find.byKey(const Key('first-login-profile')), findsOneWidget);
      expect(find.textContaining('APP for'), findsNothing);
    });

    testWidgets('Skip goes straight into the app', (tester) async {
      await enter(tester, {...testProfile(), kFirstLoginKey: true});
      await tester.tap(find.byKey(const Key('first-login-skip')));
      await tester.pumpAndSettle();
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      expect(find.byKey(const Key('first-login-profile')), findsNothing);
    });

    testWidgets('the app gets the profile without the internal flag', (
      tester,
    ) async {
      Map<String, dynamic>? seen;
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => enterApp(
                ctx,
                {...testProfile(), kFirstLoginKey: true},
                lock: makeLock(),
                homeBuilder: (p) {
                  seen = p;
                  return const Scaffold(body: Text('APP'));
                },
              ),
              child: const Text('ENTER'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ENTER'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('first-login-skip')));
      await tester.pumpAndSettle();
      expect(seen, isNotNull);
      expect(seen!.containsKey(kFirstLoginKey), isFalse);
    });

    testWidgets('Fill in profile opens the existing profile editor', (
      tester,
    ) async {
      await enter(tester, {...testProfile(), kFirstLoginKey: true});
      await tester.tap(find.byKey(const Key('first-login-profile-edit')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    });

    testWidgets('Contact to share opens the existing default contact screen', (
      tester,
    ) async {
      await enter(tester, {...testProfile(), kFirstLoginKey: true});
      await tester.tap(find.byKey(const Key('first-login-contact-edit')));
      await tester.pump();
      expect(find.byType(DefaultContactScreen), findsOneWidget);
    });

    testWidgets('no NIM is shown on the step', (tester) async {
      await enter(tester, {
        ...testProfile(),
        'nim': '12010120130001',
        kFirstLoginKey: true,
      });
      expect(find.textContaining('12010120130001'), findsNothing);
    });

    testWidgets('a returning person never sees the step', (tester) async {
      await enter(tester, testProfile());
      expect(find.byKey(const Key('first-login-profile')), findsNothing);
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
    });
  });
}
