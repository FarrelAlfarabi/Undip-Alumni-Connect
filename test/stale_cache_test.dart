import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/stale_cache.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';

Map<String, dynamic> person(String id, String name) => {
  'id': id,
  'name': name,
  'major': 'Manajemen',
  'graduation_year': 2020,
  'industry': 'Insurance',
  'city': 'Semarang',
};

Future<void> pumpDirectory(
  WidgetTester tester,
  Future<List<Map<String, dynamic>>> Function() fetch,
) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        key: UniqueKey(),
        body: DirectoryScreen(
          key: UniqueKey(),
          flagStore: MemoryLockStore(),
          currentUser: ValueNotifier({'id': 'me'}),
          fetchAlumni: fetch,
        ),
      ),
    ),
  );
}

void main() {
  test('keeps the last value and gives it back by key', () async {
    expect(StaleCache.peek<List<int>>('a'), isNull);
    await StaleCache.remember<List<int>>('a', Future.value([1, 2]));
    expect(StaleCache.peek<List<int>>('a'), [1, 2]);
    expect(StaleCache.peek<List<String>>('a'), isNull); // wrong type
    StaleCache.clear();
    expect(StaleCache.peek<List<int>>('a'), isNull);
  });

  test('a failed load keeps the old value', () async {
    await StaleCache.remember<int>('n', Future.value(1));
    await expectLater(
      StaleCache.remember<int>('n', Future.error('boom')),
      throwsA('boom'),
    );
    expect(StaleCache.peek<int>('n'), 1);
  });

  testWidgets('Members shows the last list at once while it refetches', (
    tester,
  ) async {
    await pumpDirectory(tester, () async => [person('1', 'Ayu Lestari')]);
    await tester.pumpAndSettle();
    expect(find.text('Ayu Lestari'), findsOneWidget);

    // The tab is built again (refresh window over) and the new request is slow.
    final slow = Completer<List<Map<String, dynamic>>>();
    await pumpDirectory(tester, () => slow.future);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ayu Lestari'), findsOneWidget);

    // The fresh answer replaces it.
    slow.complete([person('2', 'Budi Santoso')]);
    await tester.pumpAndSettle();
    expect(find.text('Ayu Lestari'), findsNothing);
    expect(find.text('Budi Santoso'), findsOneWidget);
  });

  testWidgets('first ever visit still shows the spinner', (tester) async {
    final slow = Completer<List<Map<String, dynamic>>>();
    await pumpDirectory(tester, () => slow.future);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    slow.complete([]);
    await tester.pumpAndSettle();
  });
}
