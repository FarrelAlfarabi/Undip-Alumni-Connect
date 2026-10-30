import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/feature_flags.dart';
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

void main() {
  test('the app ships with chat off', () => expect(chatEnabled, isFalse));

  group('switch off', () {
    testWidgets('no Message button on another alumnus profile', (tester) async {
      await pumpProfile(tester, chat: false);
      expect(find.text('Bunga Ayu'), findsOneWidget);
      expect(find.text('Message'), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    });
  });

  group('switch on (everything comes back)', () {
    testWidgets('Message button shows', (tester) async {
      await pumpProfile(tester, chat: true);
      expect(find.text('Message'), findsOneWidget);
    });
  });
}
