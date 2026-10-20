import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';

Map<String, dynamic> person(String id, String name, String city) => {
  'id': id,
  'name': name,
  'major': 'Manajemen',
  'graduation_year': 2020,
  'industry': 'Insurance',
  'city': city,
};

Future<void> pumpDirectory(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DirectoryScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          fetchAlumni: () async => [
            person('1', 'Ayu Lestari', 'Semarang'),
            person('2', 'Budi Santoso', 'Jakarta'),
            person('3', 'Citra Dewi', 'Semarang'),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows how many alumni are listed', (tester) async {
    await pumpDirectory(tester);
    expect(find.text('3 alumni'), findsOneWidget);
  });

  testWidgets('City filter narrows the list and the count says how much', (
    tester,
  ) async {
    await pumpDirectory(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semarang').last);
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso'), findsNothing);
    expect(find.text('2 dari 3 alumni'), findsOneWidget);
  });

  testWidgets('an empty result offers a way back', (tester) async {
    await pumpDirectory(tester);
    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada alumni yang cocok.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('directory-empty-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Ayu Lestari'), findsOneWidget);
    expect(find.text('3 alumni'), findsOneWidget);
  });
}
