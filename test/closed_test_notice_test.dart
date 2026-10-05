import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/policy/consent_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';
import 'package:undip_alumni_connect/widgets/closed_test_notice.dart';

/// Testers must be told, before they type anything, that this is a closed test:
/// use test contact details and do not upload real CVs. The database cannot yet
/// stop other people with the app key from reading that data (see
/// docs/AUTH_MIGRATION_PLAN.md), so the rule is part of the product for now.
void main() {
  testWidgets('the notice says what testers must not put in', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ClosedTestNotice())),
    );
    final text = tester.widget<Text>(find.byKey(const Key('closed-test-text')));
    final data = text.data!.toLowerCase();
    expect(data, contains('closed test'));
    expect(data, contains('test contact'));
    expect(data, contains('real cv'));
    expect(data, contains('phone'));
  });

  testWidgets('Welcome shows the notice', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('closed-test-notice')), findsOneWidget);
  });

  testWidgets('the consent screen shows the notice', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ConsentScreen(
          profile: const {'id': 'me', 'name': 'Siti'},
          onAccepted: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('closed-test-notice')), findsOneWidget);
  });
}
