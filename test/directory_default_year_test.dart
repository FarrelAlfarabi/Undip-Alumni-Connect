import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';

Map<String, dynamic> _p(String id, String name, int year) => {
  'id': id,
  'name': name,
  'major': 'Manajemen',
  'graduation_year': year,
  'industry': 'Banking',
};

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> me, {
  LockStore? store,
}) async {
  store ??= MemoryLockStore();
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DirectoryScreen(
          currentUser: ValueNotifier(me),
          flagStore: store,
          fetchAlumni: () async => [
            _p('1', 'Ayu Lestari', 2020),
            _p('2', 'Budi Santoso', 2018),
            _p('3', 'Citra Dewi', 2020),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('directory default year', () {
    testWidgets('second visit on the same device starts with no filter', (
      tester,
    ) async {
      final store = MemoryLockStore();
      await _pump(tester, {'id': 'me', 'graduation_year': 2020}, store: store);
      expect(find.text('Budi Santoso'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, {'id': 'me', 'graduation_year': 2020}, store: store);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Ayu Lestari'), findsOneWidget);
    });

    testWidgets('starts on the signed-in user\'s own year', (tester) async {
      await _pump(tester, {'id': 'me', 'graduation_year': 2020});
      expect(find.text('Ayu Lestari'), findsOneWidget);
      expect(find.text('Citra Dewi'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsNothing);
    });

    testWidgets('user can switch back to All years', (tester) async {
      await _pump(tester, {'id': 'me', 'graduation_year': 2020});
      await tester.tap(find.text('2020').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('All').last);
      await tester.pumpAndSettle();
      expect(find.text('Budi Santoso'), findsOneWidget);
    });

    testWidgets('no year in profile shows everyone', (tester) async {
      await _pump(tester, {'id': 'me'});
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Ayu Lestari'), findsOneWidget);
    });

    testWidgets('own year with no other members shows everyone', (
      tester,
    ) async {
      await _pump(tester, {'id': 'me', 'graduation_year': 1999});
      expect(find.text('Budi Santoso'), findsOneWidget);
    });
  });
}
