import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/marketplace_admin_screen.dart';

import '../support/fake_marketplace_api.dart';

/// SA-04: the admin's profile id is public, so admin actions also need a
/// passphrase (checked in the database). These are the app-side tests; the
/// database side is in supabase/tests/marketplace_rls_test.sql and
/// supabase/tests/security_audit/run_audit.sh post.
void main() {
  FakeApi makeApi() => FakeApi()
    ..requireAdminKey = 'right-passphrase-1234'
    ..rpcResults['marketplace_admin_pending'] = [
      listingMap(id: 'p1', status: 'pending', title: 'Pending One'),
    ]
    ..rpcResults['marketplace_report_counts'] = <Map<String, dynamic>>[];

  Future<void> pump(WidgetTester tester, FakeApi api) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceAdminScreen(
          adminId: 'admin',
          repository: MarketplaceRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asks for the passphrase and calls nothing before it', (
    tester,
  ) async {
    final api = makeApi();
    await pump(tester, api);
    expect(find.text('Admin passphrase'), findsOneWidget);
    expect(find.byKey(const Key('admin-key-field')), findsOneWidget);
    expect(api.calls, isEmpty);
    expect(find.text('Pending One'), findsNothing);
  });

  testWidgets('the passphrase field hides what is typed', (tester) async {
    await pump(tester, makeApi());
    final field = tester.widget<TextField>(
      find.byKey(const Key('admin-key-field')),
    );
    expect(field.obscureText, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
  });

  testWidgets('a wrong passphrase is refused, the queue stays hidden', (
    tester,
  ) async {
    final api = makeApi();
    await pump(tester, api);
    await tester.enterText(
      find.byKey(const Key('admin-key-field')),
      'wrong-passphrase-0000',
    );
    await tester.tap(find.byKey(const Key('admin-key-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Wrong admin passphrase'), findsOneWidget);
    expect(find.text('Pending One'), findsNothing);
    expect(find.byKey(const Key('admin-key-field')), findsOneWidget);
    // Not echoed back anywhere as visible text (the field itself is obscured).
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('wrong-passphrase'),
      ),
      findsNothing,
    );
  });

  testWidgets('an empty passphrase makes no call', (tester) async {
    final api = makeApi();
    await pump(tester, api);
    await tester.tap(find.byKey(const Key('admin-key-submit')));
    await tester.pump();
    expect(find.text('Enter the admin passphrase.'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets(
    'the right passphrase opens the queue and is sent with every call',
    (tester) async {
      final api = makeApi();
      await pump(tester, api);
      await tester.enterText(
        find.byKey(const Key('admin-key-field')),
        'right-passphrase-1234',
      );
      await tester.tap(find.byKey(const Key('admin-key-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Review queue'), findsOneWidget);
      expect(find.text('Pending One'), findsOneWidget);
      expect(
        api.params['marketplace_admin_pending']!['p_key'],
        'right-passphrase-1234',
      );
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(
        api.params['marketplace_report_counts']!['p_key'],
        'right-passphrase-1234',
      );
    },
  );

  test(
    'every admin call sends the key; a wrong key is a notAdmin error',
    () async {
      final api = makeApi()..rpcResult = listingMap(status: 'approved');
      final repo = MarketplaceRepository(api);
      await repo.fetchPending('admin', 'right-passphrase-1234');
      await repo.review(
        adminId: 'admin',
        adminKey: 'right-passphrase-1234',
        listingId: 'p1',
        approve: true,
      );
      await repo.fetchReportCounts('admin', 'right-passphrase-1234');
      for (final f in [
        'marketplace_admin_pending',
        'marketplace_review_listing',
        'marketplace_report_counts',
      ]) {
        expect(api.params[f]!['p_key'], 'right-passphrase-1234', reason: f);
      }
      await expectLater(
        repo.fetchPending('admin', 'nope'),
        throwsA(
          isA<MarketplaceException>().having(
            (e) => e.code,
            'code',
            MarketplaceErrorCode.notAdmin,
          ),
        ),
      );
    },
  );

  test('the key is never stored: no admin key in any storage or log code', () {
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      expect(
        RegExp(
          r'(secure|prefs|store)[^\n]*adminKey',
          caseSensitive: false,
        ).hasMatch(text),
        isFalse,
        reason: f.path,
      );
    }
  });
}
