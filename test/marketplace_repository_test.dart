import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/models/marketplace_listing.dart';

import 'support/fake_marketplace_api.dart';

const input = MarketplaceListingInput(
  title: 'Kopi Arabika',
  description: 'Sangrai medium',
  priceIdr: 85000,
  category: 'Food & Drink',
  city: 'Semarang',
  imageUrl: 'https://img',
  contactInfo: 'WA 0800-0000-0000',
);

void main() {
  group('MarketplaceListing.fromMap', () {
    test('parses a full row with joined seller', () {
      final l = MarketplaceListing.fromMap(
        listingMap(
          seller: {
            'id': 's1',
            'name': 'Bunga Citra Ayu',
            'faculty': 'Fakultas Ekonomika dan Bisnis',
            'major': 'Akuntansi',
            'graduation_year': 2016,
            'city': 'Jakarta',
          },
        ),
      );
      expect(l.priceIdr, 85000);
      expect(l.status, ListingStatus.approved);
      expect(l.shopUrl, isNull);
      expect(l.contactInfo, 'WA 0800-0000-0000');
      expect(l.approvedAt, DateTime.parse('2026-09-20T10:00:00+00:00'));
      expect(l.seller?.name, 'Bunga Citra Ayu');
      expect(l.seller?.graduationYear, 2016);
    });

    test('handles no seller, rejected reason, null approved_at', () {
      final l = MarketplaceListing.fromMap(
        listingMap(
          status: 'rejected',
          rejectedReason: 'Foto kurang jelas',
          approvedAt: null,
        ),
      );
      expect(l.seller, isNull);
      expect(l.status, ListingStatus.rejected);
      expect(l.rejectedReason, 'Foto kurang jelas');
      expect(l.approvedAt, isNull);
    });

    test('accepts price as a num and rejects unknown status', () {
      final m = listingMap()..['price_idr'] = 1500000.0;
      expect(MarketplaceListing.fromMap(m).priceIdr, 1500000);
      expect(
        () => MarketplaceListing.fromMap(listingMap(status: 'weird')),
        throwsFormatException,
      );
    });

    test('categories are the five agreed ones', () {
      expect(kMarketplaceCategories, [
        'Food & Drink',
        'Fashion',
        'Electronics',
        'Services',
        'Other',
      ]);
    });
  });

  group('MarketplaceRepository', () {
    late FakeApi api;
    late MarketplaceRepository repo;
    setUp(() {
      api = FakeApi();
      repo = MarketplaceRepository(api);
    });

    test('fetchApproved parses rows', () async {
      api.approved = [listingMap(id: 'a'), listingMap(id: 'b')];
      final list = await repo.fetchApproved();
      expect(list.map((l) => l.id), ['a', 'b']);
    });

    test('fetchMine calls the my_listings function', () async {
      api.rpcResult = [listingMap(status: 'pending', approvedAt: null)];
      final list = await repo.fetchMine('s1');
      expect(api.calls, ['marketplace_my_listings']);
      expect(api.params['marketplace_my_listings'], {'p_seller': 's1'});
      expect(list.single.status, ListingStatus.pending);
    });

    test('create sends every field and parses the returned row', () async {
      api.rpcResult = listingMap(status: 'pending', approvedAt: null);
      final l = await repo.create('s1', input);
      final p = api.params['marketplace_create_listing']!;
      expect(p['p_seller'], 's1');
      expect(p['p_price_idr'], 85000);
      expect(p['p_shop_url'], isNull);
      expect(p['p_contact_info'], 'WA 0800-0000-0000');
      expect(l.status, ListingStatus.pending);
    });

    test('update passes seller and listing ids', () async {
      api.rpcResult = [listingMap(status: 'pending', approvedAt: null)];
      await repo.update('s1', 'l1', input);
      final p = api.params['marketplace_update_listing']!;
      expect(p['p_seller'], 's1');
      expect(p['p_listing'], 'l1');
    });

    test('markSold and delete call their functions', () async {
      api.rpcResult = listingMap(status: 'sold');
      final sold = await repo.markSold('s1', 'l1');
      expect(sold.status, ListingStatus.sold);
      await repo.delete('s1', 'l1');
      expect(api.calls, ['marketplace_set_sold', 'marketplace_delete_listing']);
    });

    test('report sends enum name and drops a blank note', () async {
      await repo.report(
        listingId: 'l1',
        reporterId: 'r1',
        reason: ReportReason.prohibited,
        note: '   ',
      );
      await repo.report(
        listingId: 'l1',
        reporterId: 'r2',
        reason: ReportReason.spam,
        note: ' iklan ',
      );
      expect(api.reports[0], {
        'listing_id': 'l1',
        'reporter': 'r1',
        'reason': 'prohibited',
      });
      expect(api.reports[1]['note'], 'iklan');
    });

    test('maps database error codes to MarketplaceErrorCode', () async {
      final cases = {
        'subscriber_required': MarketplaceErrorCode.subscriberRequired,
        'not_owner': MarketplaceErrorCode.notOwner,
        'not_found': MarketplaceErrorCode.notFound,
        'invalid_state': MarketplaceErrorCode.invalidState,
        'something else': MarketplaceErrorCode.unknown,
      };
      for (final e in cases.entries) {
        api.throwOnCall = PostgrestException(message: e.key, code: 'P0001');
        await expectLater(
          repo.create('s1', input),
          throwsA(
            isA<MarketplaceException>().having((x) => x.code, 'code', e.value),
          ),
        );
      }
    });

    test('duplicate report becomes duplicateReport', () async {
      api.throwOnCall = PostgrestException(
        message: 'duplicate key value violates unique constraint "marketplace_reports_one_per_reporter"',
        code: '23505',
      );
      await expectLater(
        repo.report(
          listingId: 'l1',
          reporterId: 'r1',
          reason: ReportReason.spam,
        ),
        throwsA(
          isA<MarketplaceException>().having(
            (x) => x.code,
            'code',
            MarketplaceErrorCode.duplicateReport,
          ),
        ),
      );
    });
  });
}
