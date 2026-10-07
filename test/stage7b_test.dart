import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/policy_config.dart';
import 'package:undip_alumni_connect/data/feedback_repository.dart';
import 'package:undip_alumni_connect/screens/about_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';
import 'package:undip_alumni_connect/util/app_info.dart';

void main() {
  setUp(() {
    AppInfo.shared = const AppInfo(version: '0.9.0', buildNumber: '7');
  });
  tearDown(() => AppInfo.shared = null);

  test('pubspec version is 0.9.0+1', () {
    expect(
      RegExp(
        r'^version: 0\.9\.0\+1$',
        multiLine: true,
      ).hasMatch(File('pubspec.yaml').readAsStringSync()),
      isTrue,
    );
  });

  testWidgets('About shows the full label with BETA', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Lingkaran v0.9.0 (build 7) BETA'), findsOneWidget);
  });

  testWidgets('Profile has an About row that opens the About screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileDetailScreen(
          profile: {'id': 'me', 'name': 'Ahmad', 'email': 'a@example.com'},
          currentUser: ValueNotifier<Map<String, dynamic>>({
            'id': 'me',
            'name': 'Ahmad',
          }),
          adminCheck: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-help')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-about')));
    await tester.pumpAndSettle();
    expect(find.text('Lingkaran v0.9.0 (build 7) BETA'), findsOneWidget);
  });

  testWidgets('Welcome shows Beta and the version', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('BETA · v0.9.0 (build 7)'), findsOneWidget);
  });

  test('feedback reports read the version from the same place', () async {
    final r = await FeedbackRepository.build(error: 'x', screen: 'Home');
    expect(r.appVersion, '0.9.0');
    expect(r.buildNumber, '7');
  });

  testWidgets('About shows the operator name, address and email', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.byKey(const Key('about-operator')));
    final shown = text.data!;
    expect(shown, contains(kOperatorName));
    expect(shown, contains(kOperatorAddress));
    expect(shown, contains(kContactEmail));
  });
}
