import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/feature_flags.dart';
import 'package:undip_alumni_connect/screens/nearby_alumni_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

final me = {'id': 'me', 'name': 'Me', 'city': 'Semarang'};
final other = {
  'id': 'o1',
  'name': 'Bunga Ayu',
  'city': 'Jakarta',
  'current_role': 'Analyst',
  'faculty': 'FEB',
  'major': 'Manajemen',
  'graduation_year': 2020,
};

Future<void> pumpProfile(WidgetTester tester, {required bool chat}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileDetailScreen(
        profile: other,
        currentUser: ValueNotifier(me),
        showEditButton: false,
        chat: chat,
      ),
    ),
  );
}

Future<void> openCitySheet(WidgetTester tester, {required bool chat}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NearbyAlumniScreen(
          currentUser: ValueNotifier(me),
          chat: chat,
          fetchAlumni: () async => [me, other],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Map'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Jakarta ('));
  await tester.pumpAndSettle();
}

void main() {
  test('the app ships with chat off', () => expect(chatEnabled, isFalse));

  group('switch off', () {
    testWidgets('no Message button on another alumnus profile', (tester) async {
      await pumpProfile(tester, chat: false);
      expect(find.text('Bunga Ayu'), findsOneWidget);
      expect(find.text('Message'), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    });

    testWidgets('no city group chat on Nearby, WhatsApp invite stays', (
      tester,
    ) async {
      await openCitySheet(tester, chat: false);
      expect(find.textContaining('Group Chat'), findsNothing);
      expect(find.text('Invite via WhatsApp'), findsOneWidget);
      expect(find.text('Alumni here'), findsOneWidget);
    });
  });

  group('switch on (everything comes back)', () {
    testWidgets('Message button shows', (tester) async {
      await pumpProfile(tester, chat: true);
      expect(find.text('Message'), findsOneWidget);
    });

    testWidgets('city group chat button shows', (tester) async {
      await openCitySheet(tester, chat: true);
      expect(find.text('Open Jakarta Group Chat'), findsOneWidget);
    });
  });
}
