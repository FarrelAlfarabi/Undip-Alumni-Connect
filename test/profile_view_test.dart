import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

import 'support/fake_contact_api.dart';

const me = {'id': 'me', 'name': 'Ahmad Ramadhan', 'nim': '12010120'};
const other = {
  'id': 'u2',
  'name': 'Siti Azizah',
  'nim': '12010199',
  'faculty': 'Ekonomika dan Bisnis',
  'major': 'Manajemen',
  'graduation_year': 2020,
  'current_role': 'Analis',
  'company': 'PT Maju',
  'industry': 'Banking and Finance',
};

Future<void> pumpProfile(
  WidgetTester tester,
  Map<String, dynamic> profile, {
  bool own = false,
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileDetailScreen(
        profile: profile,
        currentUser: ValueNotifier(Map<String, dynamic>.from(me)),
        showEditButton: own,
        chat: false,
        contactRepository: ContactRepository(FakeContactApi()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('for others, work comes before study', (tester) async {
    await pumpProfile(tester, other);
    final work = tester.getTopLeft(find.text('EMPLOYMENT')).dy;
    final study = tester.getTopLeft(find.text('ACADEMIC')).dy;
    expect(work, lessThan(study));
  });

  testWidgets('Minta kontak stays in view outside the scrolling content', (
    tester,
  ) async {
    await pumpProfile(tester, other);
    expect(find.byKey(const Key('request-contact')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byKey(const Key('request-contact')),
      ),
      findsNothing,
    );
  });
}
