import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/home_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/models/marketplace_listing.dart';
import 'package:undip_alumni_connect/screens/admin_home_order_screen.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

Map<String, dynamic> job(int n, {int? rank, String? hiddenAt}) => {
  ...jobMap(n),
  'home_rank': rank,
  'hidden_at': hiddenAt,
};

Map<String, dynamic> orderRow(
  String id,
  String title, {
  int? rank,
  String status = 'approved',
  String owner = 'Bunga',
}) => {
  'id': id,
  'title': title,
  'owner_name': owner,
  'status': status,
  'home_rank': rank,
  'created_at': '2026-09-19T08:00:00+00:00',
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('MarketplaceListing.fromMap home_rank', () {
    test('reads the rank, null and a missing key', () {
      expect(MarketplaceListing.fromMap(listingMap(homeRank: 4)).homeRank, 4);
      expect(MarketplaceListing.fromMap(listingMap()).homeRank, isNull);
      final noKey = listingMap()..remove('home_rank');
      expect(MarketplaceListing.fromMap(noKey).homeRank, isNull);
    });
  });

  group('Home listings: pinned first, then newest', () {
    test('limits are 10 products and 3 jobs', () {
      expect(kHomeListingLimit, 10);
      expect(kHomeJobLimit, 3);
    });

    test('pinned by rank, then newest, cut to 10', () async {
      final api = FakeApi()
        ..approved = [
          for (var i = 1; i <= 14; i++)
            listingMap(
              id: 'l$i',
              title: 'L$i',
              createdAt: '2026-09-${10 + i}T08:00:00+00:00',
              homeRank: i == 2 ? 2 : (i == 5 ? 1 : null),
            ),
        ];
      final out = await homeListings(MarketplaceRepository(api));
      expect(out, hasLength(10));
      expect(out.take(2).map((l) => l.id), ['l5', 'l2']);
      // The rest are the newest, without repeating the pinned ones.
      expect(out.skip(2).map((l) => l.id).toList(), [
        'l14',
        'l13',
        'l12',
        'l11',
        'l10',
        'l9',
        'l8',
        'l7',
      ]);
    });

    test('a pinned item older than the newest 20 is still found', () async {
      final api = FakeApi()
        ..approved = [
          for (var i = 1; i <= 30; i++)
            listingMap(
              id: 'l$i',
              createdAt:
                  '2026-08-${i.toString().padLeft(2, '0')}T08:00:00+00:00',
              homeRank: i == 1 ? 1 : null,
            ),
        ];
      final out = await homeListings(MarketplaceRepository(api));
      expect(out.first.id, 'l1');
      expect(api.calls, containsAll(['select', 'select-pinned']));
    });

    test(
      'pinned items that are not approved are skipped, no slot used',
      () async {
        final api = FakeApi()
          ..approved = [
            listingMap(id: 'rej', status: 'rejected', homeRank: 1),
            listingMap(id: 'sold', status: 'sold', homeRank: 2),
            listingMap(id: 'ok', homeRank: 3),
            for (var i = 1; i <= 12; i++)
              listingMap(
                id: 'n$i',
                createdAt: '2026-09-${10 + i}T08:00:00+00:00',
              ),
          ];
        final out = await homeListings(MarketplaceRepository(api));
        expect(out.map((l) => l.id), isNot(contains('rej')));
        expect(out.map((l) => l.id), isNot(contains('sold')));
        expect(out.first.id, 'ok');
        expect(out, hasLength(10));
      },
    );

    test('a hidden pinned item is skipped', () async {
      final hidden = listingMap(id: 'h', homeRank: 1)
        ..['hidden_at'] = '2026-09-20T08:00:00+00:00';
      final api = FakeApi()..approved = [hidden, listingMap(id: 'n')];
      final out = await homeListings(MarketplaceRepository(api));
      expect(out.map((l) => l.id), ['n']);
    });

    test('keeps asking the server for a capped number of newest', () async {
      final api = FakeApi()..approved = [listingMap()];
      await homeListings(MarketplaceRepository(api));
      expect(api.lastLimit, kHomeListingFetchLimit);
    });
  });

  group('Home jobs: pinned first, then newest', () {
    test('pinned by rank, then newest, cut to 3', () async {
      final api = FakeHomeApi(
        jobs: [job(5), job(4), job(3, rank: 2), job(2, rank: 1), job(1)],
      );
      final out = await homeJobs(api);
      expect(out.map((j) => j['id']), ['j2', 'j3', 'j5']);
    });

    test('a hidden pinned job is skipped and uses no slot', () async {
      final api = FakeHomeApi(
        jobs: [
          job(4, rank: 1, hiddenAt: '2026-09-20T08:00:00+00:00'),
          job(3),
          job(2),
          job(1),
        ],
      );
      final out = await homeJobs(api);
      expect(out.map((j) => j['id']), ['j3', 'j2', 'j1']);
    });

    test('a pinned job from a blocked poster is skipped', () async {
      final blocked = job(2, rank: 1)..['posted_by'] = 'bad';
      final api = FakeHomeApi(jobs: [blocked, job(1)]);
      final out = await homeJobs(api, isBlocked: (id) => id == 'bad');
      expect(out.map((j) => j['id']), ['j1']);
    });
  });

  group('AdminRepository home order', () {
    test('setHomeOrder sends the admin id, kind and full id list', () async {
      final api = FakeAdminApi();
      await AdminRepository(api)
          .setHomeOrder(adminId: 'me', kind: 'job', ids: ['a', 'b']);
      expect(api.params['admin_set_home_order'], {
        'p_admin': 'me',
        'p_kind': 'job',
        'p_ids': ['a', 'b'],
      });
    });

    test('items parses rows and knows what Home would show', () async {
      final api = FakeAdminApi()
        ..results['admin_home_order_list'] = [
          orderRow('a', 'A', rank: 1),
          orderRow('b', 'B', rank: 2, status: 'sold'),
          orderRow('c', 'C'),
        ];
      final items = await AdminRepository(api).homeOrderItems('me', 'listing');
      expect(api.params['admin_home_order_list'], {
        'p_admin': 'me',
        'p_kind': 'listing',
      });
      expect(items.map((i) => i.rank), [1, 2, null]);
      expect(items.map((i) => i.isShown), [true, false, true]);
      expect(items.first.ownerName, 'Bunga');
    });
  });

  group('Home order screen', () {
    Future<FakeAdminApi> open(
      WidgetTester tester, {
      List<Map<String, dynamic>>? products,
      List<Map<String, dynamic>>? jobs,
    }) async {
      phone(tester);
      final api = FakeAdminApi()
        ..results['admin_home_order_list'] = products ?? <dynamic>[];
      final repo = AdminRepository(api);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeOrderScreen(adminId: 'me', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    List<String> lastIds(FakeAdminApi api) =>
        List<String>.from(api.params['admin_set_home_order']!['p_ids'] as List);

    testWidgets('shows the rule line and both chips', (tester) async {
      await open(tester);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Jobs'), findsOneWidget);
      expect(
        find.textContaining('Tampil di Home: 10 produk, 3 lowongan'),
        findsOneWidget,
      );
    });

    testWidgets('empty state', (tester) async {
      await open(tester);
      expect(find.text('Belum ada produk yang disetujui.'), findsOneWidget);
    });

    testWidgets('error state offers a retry', (tester) async {
      phone(tester);
      final api = FakeAdminApi()
        ..throwOnCall = const AdminException(
          AdminErrorCode.notAdmin,
          'not_admin',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeOrderScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You are not an admin.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('pinned items come first in rank order, others below', (
      tester,
    ) async {
      await open(
        tester,
        products: [
          orderRow('a', 'Kopi', rank: 2),
          orderRow('b', 'Batik', rank: 1),
          orderRow('c', 'Madu'),
        ],
      );
      expect(find.text('Dipin'), findsOneWidget);
      expect(find.text('Belum dipin'), findsOneWidget);
      final batik = tester.getTopLeft(find.text('Batik')).dy;
      final kopi = tester.getTopLeft(find.text('Kopi')).dy;
      final madu = tester.getTopLeft(find.text('Madu')).dy;
      expect(batik, lessThan(kopi));
      expect(kopi, lessThan(madu));
    });

    testWidgets('Pin adds the item to the end of the pinned list', (
      tester,
    ) async {
      final api = await open(
        tester,
        products: [orderRow('a', 'Kopi', rank: 1), orderRow('c', 'Madu')],
      );
      await tester.tap(find.byKey(const Key('home-order-pin-c')));
      await tester.pumpAndSettle();
      expect(lastIds(api), ['a', 'c']);
      expect(api.params['admin_set_home_order']!['p_kind'], 'listing');
    });

    testWidgets('moving up and down sends the new order in one call', (
      tester,
    ) async {
      final api = await open(
        tester,
        products: [
          orderRow('a', 'Kopi', rank: 1),
          orderRow('b', 'Batik', rank: 2),
          orderRow('c', 'Madu', rank: 3),
        ],
      );
      await tester.tap(find.byKey(const Key('home-order-up-c')));
      await tester.pumpAndSettle();
      expect(lastIds(api), ['a', 'c', 'b']);
      await tester.tap(find.byKey(const Key('home-order-down-a')));
      await tester.pumpAndSettle();
      expect(lastIds(api), ['b', 'a', 'c']);
      expect(api.calls.where((c) => c == 'admin_set_home_order'), hasLength(2));
    });

    testWidgets('Lepas removes the item from the pinned list', (tester) async {
      final api = await open(
        tester,
        products: [
          orderRow('a', 'Kopi', rank: 1),
          orderRow('b', 'Batik', rank: 2),
        ],
      );
      await tester.tap(find.byKey(const Key('home-order-unpin-a')));
      await tester.pumpAndSettle();
      expect(lastIds(api), ['b']);
    });

    testWidgets('Pin is disabled once Home is full of pinned products', (
      tester,
    ) async {
      final api = await open(
        tester,
        products: [
          for (var i = 1; i <= 10; i++) orderRow('p$i', 'Pinned $i', rank: i),
          orderRow('x', 'Extra'),
        ],
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('home-order-pin-x')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('home-order-pin-x')));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('admin_set_home_order')));
      expect(find.textContaining('Lepas satu pin dulu'), findsWidgets);
    });

    testWidgets(
      'a pinned item Home would not show is tagged and uses no slot',
      (tester) async {
        await open(
          tester,
          products: [
            orderRow('a', 'Laku', rank: 1, status: 'sold'),
            orderRow('b', 'Kopi', rank: 2),
          ],
        );
        expect(find.text('Terjual'), findsOneWidget);
        expect(find.text('Tidak tampil di Home'), findsOneWidget);
      },
    );

    testWidgets('Jobs chip loads jobs and pins with kind job', (tester) async {
      final api = await open(tester, products: [orderRow('a', 'Kopi')]);
      api.results['admin_home_order_list'] = [orderRow('j1', 'Analis')];
      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();
      expect(api.params['admin_home_order_list']!['p_kind'], 'job');
      await tester.tap(find.byKey(const Key('home-order-pin-j1')));
      await tester.pumpAndSettle();
      expect(api.params['admin_set_home_order']!['p_kind'], 'job');
      expect(lastIds(api), ['j1']);
    });

    testWidgets('a failed save shows the error and reloads the list', (
      tester,
    ) async {
      final api = await open(tester, products: [orderRow('c', 'Madu')]);
      api.throwOnCall = const AdminException(AdminErrorCode.unknown, 'boom');
      final before = api.calls
          .where((c) => c == 'admin_home_order_list')
          .length;
      await tester.tap(find.byKey(const Key('home-order-pin-c')));
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(
        api.calls.where((c) => c == 'admin_home_order_list').length,
        before + 1,
      );
    });

    testWidgets('search filters the unpinned list', (tester) async {
      await open(
        tester,
        products: [orderRow('a', 'Kopi'), orderRow('b', 'Batik')],
      );
      await tester.enterText(find.byKey(const Key('home-order-search')), 'bat');
      await tester.pump();
      expect(find.text('Batik'), findsOneWidget);
      expect(find.text('Kopi'), findsNothing);
    });
  });

  testWidgets('Admin home lists Home order and opens it', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          adminId: 'me',
          adminRepository: AdminRepository(FakeAdminApi()),
          marketplaceRepository: MarketplaceRepository(FakeApi()),
        ),
      ),
    );
    final tile = find.byKey(const Key('admin-home-order'));
    expect(tile, findsOneWidget);
    expect(find.text('Home order'), findsOneWidget);
    expect(
      find.text('Pilih produk dan lowongan yang tampil dulu di Home'),
      findsOneWidget,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(AdminHomeOrderScreen), findsOneWidget);
  });
}
