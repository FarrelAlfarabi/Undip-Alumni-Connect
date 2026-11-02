import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';
import 'package:undip_alumni_connect/widgets/linkedin_logo.dart';
import 'package:undip_alumni_connect/widgets/marketplace_demo_notice.dart';

void main() {
  testWidgets('Tutup closes the dialog and hides the notice card', (
    tester,
  ) async {
    MarketplaceDemoNotice.resetForTest();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MarketplaceDemoNotice())),
    );
    expect(find.byKey(const Key('marketplace-notice')), findsOneWidget);
    await tester.tap(find.byKey(const Key('marketplace-notice')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('marketplace-notice')), findsNothing);
    MarketplaceDemoNotice.resetForTest();
  });

  testWidgets('member LinkedIn button shows the LinkedIn logo', (tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DirectoryScreen(
            flagStore: MemoryLockStore(),
            currentUser: ValueNotifier({'id': 'me'}),
            fetchAlumni: () async => [
              {
                'id': 'a1',
                'name': 'Ayu',
                'major': 'Manajemen',
                'graduation_year': 2020,
                'linkedin_url': 'https://linkedin.com/in/ayu',
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('member-linkedin-a1')),
        matching: find.byType(LinkedInLogo),
      ),
      findsOneWidget,
    );
  });
}
