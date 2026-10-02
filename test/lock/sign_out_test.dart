import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/lock/session.dart';

import '../support/fake_lock.dart';

void main() {
  testWidgets(
    'sign out forgets who is signed in, keeps the PIN, and tears down the stack',
    (tester) async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      lock.sessionActive = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    signOutTo(context, const Text('VERIFY'), lock: lock),
                child: const Text('SIGN OUT'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SIGN OUT'));
      await tester.pumpAndSettle();
      expect(find.text('VERIFY'), findsOneWidget);
      expect(find.text('SIGN OUT'), findsNothing);
      expect(await lock.load(), isNull);
      expect(await lock.hasPin(), isTrue);
      expect(lock.sessionActive, isFalse);
      expect(store.data.values.join().contains('Ahmad'), isFalse);
    },
  );
}
