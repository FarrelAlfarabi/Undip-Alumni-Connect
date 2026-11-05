import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_format.dart';
import 'package:undip_alumni_connect/data/marketplace_validation.dart';
import 'package:undip_alumni_connect/models/marketplace_listing.dart';

import 'marketplace_seller_test.dart'
    show fillValid, openForm, pumpFormLauncher, useTallPhone;
import 'support/fake_marketplace_api.dart';

void main() {
  group('price label', () {
    test('price only', () {
      expect(priceLabel(85000, false), 'Rp 85.000');
    });
    test('price and negotiable', () {
      expect(priceLabel(85000, true), 'Rp 85.000 (nego)');
    });
    test('negotiable with no price written', () {
      expect(priceLabel(null, true), 'Harga nego');
    });
    test('no price and not negotiable', () {
      expect(priceLabel(null, false), 'Hubungi penjual');
    });
  });

  group('validation', () {
    test('price is needed unless negotiable', () {
      expect(MarketplaceValidation.priceFor('', negotiable: false), isNotNull);
      expect(MarketplaceValidation.priceFor('', negotiable: true), isNull);
      expect(
        MarketplaceValidation.priceFor('abc', negotiable: true),
        isNotNull,
      );
      expect(MarketplaceValidation.priceFor('5000', negotiable: false), isNull);
    });
    test('city is optional', () {
      expect(MarketplaceValidation.city(''), isNull);
      expect(MarketplaceValidation.city(null), isNull);
      expect(MarketplaceValidation.city('a' * 61), isNotNull);
    });
  });

  test('a listing with no price and no city loads', () {
    final l = MarketplaceListing.fromMap({
      ...listingMap(),
      'price_idr': null,
      'price_negotiable': true,
      'city': null,
    });
    expect(l.priceIdr, isNull);
    expect(l.priceNegotiable, isTrue);
    expect(l.city, '');
  });

  group('form', () {
    testWidgets('negotiable with no price and no city can be posted', (
      tester,
    ) async {
      useTallPhone(tester);
      final api = FakeApi()
        ..rpcResults['marketplace_create_listing'] = listingMap();
      await pumpFormLauncher(tester, api);
      await openForm(tester);
      await fillValid(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Price (whole rupiah)'),
        '',
      );
      await tester.ensureVisible(find.byKey(const Key('price-negotiable')));
      await tester.tap(find.byKey(const Key('price-negotiable')));
      await tester.pump();
      await tester.ensureVisible(find.text('Post product'));
      await tester.tap(find.text('Post product'));
      await tester.pumpAndSettle();
      final p = api.params['marketplace_create_listing']!;
      expect(p['p_price_idr'], isNull);
      expect(p['p_price_negotiable'], true);
      expect(p['p_city'], isNull);
    });

    testWidgets('not negotiable still needs a price', (tester) async {
      useTallPhone(tester);
      final api = FakeApi();
      await pumpFormLauncher(tester, api);
      await openForm(tester);
      await fillValid(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Price (whole rupiah)'),
        '',
      );
      await tester.ensureVisible(find.text('Post product'));
      await tester.tap(find.text('Post product'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('a city can be picked and then cleared', (tester) async {
      useTallPhone(tester);
      final api = FakeApi()
        ..rpcResults['marketplace_create_listing'] = listingMap();
      await pumpFormLauncher(tester, api);
      await openForm(tester);
      expect(find.byKey(const Key('city-clear')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('city-choice')));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('city-choice')),
          matching: find.byType(TextField),
        ),
        'Semarang',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semarang').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('city-clear')), findsOneWidget);
      await tester.tap(find.byKey(const Key('city-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('city-clear')), findsNothing);
    });
  });
}
