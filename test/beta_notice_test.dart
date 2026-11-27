import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/policy/consent_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';

/// The app is released as a beta: the consent screen carries a light beta note
/// (it may have bugs, send feedback). It must not tell people to avoid real data.
void main() {
  testWidgets('Welcome does not show the notice', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('beta-notice')), findsNothing);
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
    expect(find.byKey(const Key('beta-notice')), findsOneWidget);
    expect(find.textContaining('CV asli'), findsNothing);
    expect(find.textContaining('data kontak percobaan'), findsNothing);
  });
}
