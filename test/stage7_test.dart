import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/home_screen.dart';
import 'package:undip_alumni_connect/screens/market_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

import 'support/fake_business_api.dart';
import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

final me = ValueNotifier<Map<String, dynamic>>({
  'id': 'me',
  'name': 'Ahmad Ramadhan',
});

void phone(WidgetTester tester, {double h = 2200}) {
  tester.view.physicalSize = Size(420, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Business biz({
  String status = 'approved',
  String? band = 'micro',
  String? reason,
  String? until,
  String? reviewedAt,
}) => Business.fromMap(
  businessMap(
    reviewedAt: reviewedAt ?? DateTime.now().toIso8601String(),
    status: status,
    approvedBand: status == 'approved' ? band : null,
    reason: reason,
    unlimitedUntil: until,
  ),
);

BusinessUsage usage({int used = 2, int limit = 3, bool unlimited = false}) =>
    BusinessUsage(
      businessId: 'b1',
      freeLimit: limit,
      used: used,
      unlimitedActive: unlimited,
      canPost: unlimited || used < limit,
    );

void main() {
  group('Market tab', () {
    Future<ValueNotifier<int>> pump(WidgetTester tester) async {
      phone(tester);
      final segment = ValueNotifier(0);
      final market = FakeApi()
        ..approved = [listingMap(title: 'Kopi Arabika', seller: sellerMap)];
      final bizApi = FakeBusinessApi()
        ..results['business_directory'] = [
          {
            ...businessMap(id: '1', name: 'Toko Batik', status: 'approved'),
            'owner_name': 'Siti',
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: MarketScreen(
            currentUser: me,
            segment: segment,
            marketplaceRepository: MarketplaceRepository(market),
            businessRepository: BusinessRepository(bizApi),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return segment;
    }

    testWidgets('two segments: Products first, Businesses second', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Businesses'), findsOneWidget);
      expect(find.text('Kopi Arabika'), findsOneWidget);
      // One title only: the inner screens have no app bar of their own.
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Market'), findsOneWidget);
    });

    testWidgets(
      'tapping Businesses shows the directory, and the segment can be set from outside',
      (tester) async {
        final segment = await pump(tester);
        await tester.tap(find.text('Businesses'));
        await tester.pumpAndSettle();
        expect(segment.value, 1);
        expect(find.text('Toko Batik'), findsOneWidget);
        segment.value = 0;
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SegmentedButton<int>>(
                find.byKey(const Key('market-segments')),
              )
              .selected,
          {0},
        );
      },
    );

    testWidgets('each segment keeps its own actions', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('my-listings')), findsOneWidget);
      expect(find.text('Add a product'), findsOneWidget);
      await tester.tap(find.text('Businesses'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my-businesses')), findsOneWidget);
      expect(find.text('Register a business'), findsOneWidget);
    });
  });

  group('Home business card', () {
    Future<FakeHomeApi> pumpHome(WidgetTester tester, FakeHomeApi api) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentUser: me,
            onOpenDirectory: () {},
            pages: fakePages(),
            api: api,
            marketplaceRepository: MarketplaceRepository(FakeApi()),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      return api;
    }

    testWidgets('no business: a "register your business" card instead', (
      tester,
    ) async {
      await pumpHome(tester, FakeHomeApi());
      expect(find.byKey(const Key('business-register-card')), findsOneWidget);
      expect(find.byKey(const Key('business-owner-card')), findsNothing);
      await tester.tap(find.byKey(const Key('business-register-button')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE RegisterBusiness'), findsOneWidget);
    });

    testWidgets('owner card: status, band, products used out of the limit', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeApi(businesses: [biz()], usage: [usage()]),
      );
      expect(find.byKey(const Key('business-owner-card')), findsOneWidget);
      expect(find.byKey(const Key('business-register-card')), findsNothing);
      expect(find.text('Kopi Ahmad'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Band: Micro'), findsOneWidget);
      expect(
        find.text('Products posted: 2 of 3 allowed for free'),
        findsOneWidget,
      );
    });

    testWidgets('owner card: days of unlimited posting left', (tester) async {
      final until = DateTime.now().add(const Duration(days: 12));
      final iso =
          '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}';
      await pumpHome(
        tester,
        FakeHomeApi(
          businesses: [biz(until: iso)],
          usage: [usage(used: 5, unlimited: true)],
        ),
      );
      expect(find.textContaining('unlimited posting until'), findsOneWidget);
      expect(find.textContaining('12 days left'), findsOneWidget);
    });

    testWidgets('approved card goes away 3 days after approval', (
      tester,
    ) async {
      final old = DateTime.now()
          .subtract(const Duration(days: 4))
          .toIso8601String();
      await pumpHome(
        tester,
        FakeHomeApi(
          businesses: [biz(reviewedAt: old)],
          usage: [usage()],
        ),
      );
      expect(find.byKey(const Key('business-owner-card')), findsNothing);
      expect(find.byKey(const Key('business-register-card')), findsNothing);
    });

    test('a business that needs attention always shows', () {
      final now = DateTime.now();
      final old = now.subtract(const Duration(days: 30)).toIso8601String();
      final approved = biz(reviewedAt: old);
      final pending = biz(status: 'pending', band: null, reviewedAt: old);
      expect(businessForHomeCard([approved], now), isNull);
      expect(businessForHomeCard([approved, pending], now), same(pending));
    });

    testWidgets('owner card: pending and rejected show what the owner needs', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeApi(businesses: [biz(status: 'pending', band: null)]),
      );
      expect(find.text('Waiting for review'), findsOneWidget);
      expect(find.text('Band you chose: Small'), findsOneWidget);
      expect(find.textContaining('Products:'), findsNothing);
    });

    testWidgets('rejected: the reason', (tester) async {
      await pumpHome(
        tester,
        FakeHomeApi(
          businesses: [biz(status: 'rejected', reason: 'Link rusak')],
        ),
      );
      expect(find.text('Not approved'), findsOneWidget);
      expect(find.text('Reason: Link rusak'), findsOneWidget);
    });

    testWidgets(
      'several businesses: the approved one shows, with a "+ N more"',
      (tester) async {
        await pumpHome(
          tester,
          FakeHomeApi(
            businesses: [
              Business.fromMap(
                businessMap(id: 'x', name: 'Baru', status: 'pending'),
              ),
              Business.fromMap(
                businessMap(
                  id: 'b1',
                  name: 'Kopi Ahmad',
                  status: 'approved',
                  approvedBand: 'micro',
                  reviewedAt: DateTime.now().toIso8601String(),
                ),
              ),
            ],
            usage: [usage()],
          ),
        );
        expect(find.text('Kopi Ahmad'), findsOneWidget);
        expect(find.text('+ 1 more'), findsOneWidget);
      },
    );

    testWidgets('tapping the owner card opens My businesses', (tester) async {
      await pumpHome(
        tester,
        FakeHomeApi(businesses: [biz()], usage: [usage()]),
      );
      await tester.tap(find.byKey(const Key('business-owner-card')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE MyBusinesses'), findsOneWidget);
    });

    testWidgets('a failed load shows no card and Home still works', (
      tester,
    ) async {
      await pumpHome(tester, FakeHomeApi(businessesError: Exception('boom')));
      expect(find.byKey(const Key('business-owner-card')), findsNothing);
      expect(find.byKey(const Key('business-register-card')), findsNothing);
      expect(find.text('Hello, Ahmad'), findsOneWidget);
    });

    testWidgets('Requests badge and notification bell are in the app bar', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeApi(pendingRequests: 2, unreadNotifications: 3),
      );
      expect(find.byKey(const Key('requests-badge')), findsOneWidget);
      expect(find.byKey(const Key('notifications-badge')), findsOneWidget);
    });
  });

  group('Profile list', () {
    Future<void> pump(WidgetTester tester, {required bool admin}) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileDetailScreen(
            profile: {'id': 'me', 'name': 'Ahmad', 'email': 'a@example.com'},
            currentUser: me,
            adminCheck: (_) async => admin,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'My business, Blocked users, Privacy policy, Delete my account',
      (tester) async {
        await pump(tester, admin: false);
        for (final k in [
          'profile-business',
          'profile-blocked',
          'profile-policy',
          'profile-delete',
        ]) {
          expect(find.byKey(Key(k)), findsOneWidget, reason: k);
        }
        expect(find.byKey(const Key('profile-admin')), findsNothing);
        expect(find.text('My business'), findsOneWidget);
        expect(find.text('Blocked users'), findsOneWidget);
        expect(find.text('Privacy policy and community rules'), findsOneWidget);
      },
    );

    testWidgets('Admin only for admins, Delete is last', (tester) async {
      await pump(tester, admin: true);
      expect(find.byKey(const Key('profile-admin')), findsOneWidget);
      double y(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
      expect(y('profile-business') < y('profile-blocked'), isTrue);
      expect(y('profile-blocked') < y('profile-policy'), isTrue);
      expect(y('profile-policy') < y('profile-admin'), isTrue);
      expect(y('profile-admin') < y('profile-delete'), isTrue);
    });
  });
}
