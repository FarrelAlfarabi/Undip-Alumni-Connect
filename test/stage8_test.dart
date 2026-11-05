import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

void main() {
  testWidgets('Profile has a Send feedback row that opens the sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileDetailScreen(
          profile: {'id': 'me', 'name': 'Ahmad', 'email': 'a@example.com'},
          currentUser: ValueNotifier<Map<String, dynamic>>({'id': 'me'}),
          adminCheck: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-help')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-feedback')));
    await tester.pumpAndSettle();
    expect(find.text('Send feedback'), findsWidgets);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
