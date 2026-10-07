import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_messages.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/data/posting_text.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/marketplace_form_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_screen.dart';
import 'package:undip_alumni_connect/screens/my_businesses_screen.dart';

import 'support/fake_business_api.dart';
import 'support/fake_marketplace_api.dart';

Map<String, dynamic> usageMap({
  String id = 'b1',
  int limit = 3,
  int used = 0,
  bool unlimited = false,
  bool? canPost,
}) => {
  'business_id': id,
  'free_post_limit': limit,
  'products_used': used,
  'unlimited_active': unlimited,
  'can_post': canPost ?? (unlimited || used < limit),
};

void main() {
  group('contact info field', () {
    testWidgets('keeps its label, one field, 300 limit, new hint', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceFormScreen(
            sellerId: 's1',
            businessId: 'b1',
            repository: MarketplaceRepository(FakeApi()),
          ),
        ),
      );
      final field = find.widgetWithText(
        TextFormField,
        'Contact info (optional)',
      );
      expect(field, findsOneWidget);
      final input = tester.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      );
      expect(
        input.decoration!.hintText,
        'WhatsApp, phone, email, social media...',
      );
      expect(input.maxLength, 300);
      expect(find.text('WhatsApp, email, phone...'), findsNothing);
    });
  });

  group('posting text', () {
    final b = Business.fromMap(
      businessMap(
        status: 'approved',
        approvedBand: 'micro',
        unlimitedUntil: '2026-11-05',
      ),
    );
    final today = DateTime(2026, 10, 13);

    test('free: used out of limit', () {
      expect(
        postingSummary(
          b,
          BusinessUsage.fromMap(usageMap(used: 2)),
          today: today,
        ),
        'Products posted: 2 of 3 allowed for free',
      );
    });

    test('unlimited: end date and days left', () {
      final u = BusinessUsage.fromMap(usageMap(used: 5, unlimited: true));
      expect(
        postingSummary(b, u, today: today),
        'Products posted: 5, unlimited posting until 5 Nov 2026 (23 days left)',
      );
      expect(
        postingSummary(b, u, today: DateTime(2026, 11, 4)),
        contains('(1 day left)'),
      );
      expect(
        postingSummary(b, u, today: DateTime(2026, 11, 5)),
        contains('(last day)'),
      );
    });

    test('over the limit after expiry: stays visible, new blocked', () {
      final u = BusinessUsage.fromMap(usageMap(used: 5, canPost: false));
      final t = postingSummary(b, u, today: today);
      expect(t, contains('5 of 3'));
      expect(t, contains('stay visible'));
      expect(t, contains('new ones are blocked'));
    });

    test('no price and no payment words anywhere', () {
      for (final t in [
        postingSummary(
          b,
          BusinessUsage.fromMap(usageMap(used: 3, canPost: false)),
          today: today,
        ),
        kPostLimitMessage,
        kProductsNeedBusinessMessage,
      ]) {
        expect(t.toLowerCase(), isNot(contains('rp ')));
        expect(t.toLowerCase(), isNot(contains('transfer')));
        expect(t.toLowerCase(), isNot(contains('pay')));
        expect(t.toLowerCase(), isNot(contains('rekening')));
      }
    });
  });

  group('owner card', () {
    testWidgets('shows approved band, products used out of limit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeBusinessApi()
        ..results['business_my'] = [
          businessMap(status: 'approved', approvedBand: 'micro'),
        ]
        ..results['business_my_usage'] = [usageMap(used: 2)];
      await tester.pumpWidget(
        MaterialApp(
          home: MyBusinessesScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Approved band: Micro'), findsOneWidget);
      expect(
        find.text('Products posted: 2 of 3 allowed for free'),
        findsOneWidget,
      );
    });

    testWidgets('unlimited shows the end date with days left', (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final until = DateTime.now().add(const Duration(days: 9));
      final iso =
          '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}';
      final api = FakeBusinessApi()
        ..results['business_my'] = [
          businessMap(
            status: 'approved',
            approvedBand: 'micro',
            unlimitedUntil: iso,
          ),
        ]
        ..results['business_my_usage'] = [usageMap(used: 6, unlimited: true)];
      await tester.pumpWidget(
        MaterialApp(
          home: MyBusinessesScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('unlimited posting until'), findsOneWidget);
      expect(find.textContaining('9 days left'), findsOneWidget);
    });
  });

  group('Add a product flow', () {
    Future<FakeBusinessApi> pump(
      WidgetTester tester, {
      required List<Map<String, dynamic>> businesses,
      required List<Map<String, dynamic>> usage,
    }) async {
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bizApi = FakeBusinessApi()
        ..results['business_my'] = businesses
        ..results['business_my_usage'] = usage;
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceScreen(
            currentUser: ValueNotifier({'id': 'me', 'city': 'Semarang'}),
            repository: MarketplaceRepository(FakeApi()..approved = []),
            businessRepository: BusinessRepository(bizApi),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return bizApi;
    }

    testWidgets('no business: explains and offers to register', (tester) async {
      await pump(tester, businesses: [], usage: []);
      await tester.tap(find.text('Add a product'));
      await tester.pumpAndSettle();
      expect(find.text(kProductsNeedBusinessMessage), findsOneWidget);
      await tester.tap(find.text('Register a business'));
      await tester.pumpAndSettle();
      expect(find.text('Business name *'), findsOneWidget);
    });

    testWidgets('a pending business does not allow products', (tester) async {
      await pump(
        tester,
        businesses: [businessMap(status: 'pending')],
        usage: [usageMap(canPost: false)],
      );
      await tester.tap(find.text('Add a product'));
      await tester.pumpAndSettle();
      expect(find.text(kProductsNeedBusinessMessage), findsOneWidget);
      expect(find.text('Post product'), findsNothing);
    });

    testWidgets(
      'at the free limit: shows used and limit, contact admin, no payment',
      (tester) async {
        await pump(
          tester,
          businesses: [businessMap(status: 'approved', approvedBand: 'micro')],
          usage: [usageMap(used: 3, canPost: false)],
        );
        await tester.tap(find.text('Add a product'));
        await tester.pumpAndSettle();
        expect(find.text('Free limit reached'), findsOneWidget);
        expect(
          find.textContaining('used 3 of 3 free products'),
          findsOneWidget,
        );
        expect(
          find.textContaining('contact an admin about unlimited posting'),
          findsOneWidget,
        );
        expect(find.text('Post product'), findsNothing);
        expect(find.textContaining('Rp'), findsNothing);
      },
    );

    testWidgets('under the limit: the product form opens', (tester) async {
      await pump(
        tester,
        businesses: [businessMap(status: 'approved', approvedBand: 'micro')],
        usage: [usageMap(used: 1)],
      );
      await tester.tap(find.text('Add a product'));
      await tester.pumpAndSettle();
      expect(find.text('Post product'), findsOneWidget);
    });

    testWidgets('two approved businesses: pick one first', (tester) async {
      await pump(
        tester,
        businesses: [
          businessMap(
            id: 'b1',
            name: 'Kopi',
            status: 'approved',
            approvedBand: 'micro',
          ),
          businessMap(
            id: 'b2',
            name: 'Batik',
            status: 'approved',
            approvedBand: 'small',
          ),
        ],
        usage: [
          usageMap(id: 'b1'),
          usageMap(id: 'b2'),
        ],
      );
      await tester.tap(find.text('Add a product'));
      await tester.pumpAndSettle();
      expect(find.text('Add a product to which business?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pick-b2')));
      await tester.pumpAndSettle();
      expect(find.text('Post product'), findsOneWidget);
    });
  });
}
