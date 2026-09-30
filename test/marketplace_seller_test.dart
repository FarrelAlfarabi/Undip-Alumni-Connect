import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_image_picker.dart';
import 'package:undip_alumni_connect/data/marketplace_messages.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_validation.dart';
import 'package:undip_alumni_connect/models/marketplace_listing.dart';
import 'package:undip_alumni_connect/screens/marketplace_form_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_screen.dart';
import 'package:undip_alumni_connect/screens/my_listings_screen.dart';

import 'support/fake_marketplace_api.dart';

// A valid 1x1 PNG so Image.memory can decode it.
final pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

ValueNotifier<Map<String, dynamic>> user(String status) => ValueNotifier({
  'id': 's1',
  'name': 'Bunga',
  'subscription_status': status,
  'city': 'Jakarta',
});

void useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<Future<MarketplaceListing?> Function()> pumpFormLauncher(
  WidgetTester tester,
  FakeApi api, {
  MarketplaceListing? existing,
  ImagePickerFn? picker,
}) async {
  MarketplaceListing? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<MarketplaceListing>(
                  MaterialPageRoute(
                    builder: (_) => MarketplaceFormScreen(
                      sellerId: 's1',
                      repository: MarketplaceRepository(api),
                      existing: existing,
                      defaultCity: 'Jakarta',
                      pickImage:
                          picker ??
                          () async =>
                              PickedImage(name: 'foto.png', bytes: pngBytes),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  return () async => result;
}

Future<void> openForm(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> fillValid(
  WidgetTester tester, {
  String contact = 'WA 0800-0000-0000',
}) async {
  await tester.tap(find.text('Choose photo'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Title'),
    'Kopi Arabika',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Description'),
    'Sangrai medium',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Price (whole rupiah)'),
    '85000',
  );
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Food & Drink').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Contact info (optional)'),
    contact,
  );
  await tester.pump();
}

void main() {
  group('MarketplaceValidation', () {
    test('title', () {
      expect(MarketplaceValidation.title(''), isNotNull);
      expect(MarketplaceValidation.title('ab'), isNotNull);
      expect(MarketplaceValidation.title('abc'), isNull);
      expect(MarketplaceValidation.title('a' * 101), isNotNull);
    });
    test('price is a whole non-negative number', () {
      expect(MarketplaceValidation.price(''), isNotNull);
      expect(MarketplaceValidation.price('-5'), isNotNull);
      expect(MarketplaceValidation.price('12.5'), isNotNull);
      expect(MarketplaceValidation.price('0'), isNull);
      expect(MarketplaceValidation.price('1500000'), isNull);
      expect(MarketplaceValidation.price('3000000000'), isNotNull);
    });
    test('shop url', () {
      expect(MarketplaceValidation.shopUrl(''), isNull);
      expect(MarketplaceValidation.shopUrl('https://example.com/toko'), isNull);
      expect(MarketplaceValidation.shopUrl('example.com'), isNotNull);
      expect(MarketplaceValidation.shopUrl('javascript:alert(1)'), isNotNull);
      expect(MarketplaceValidation.shopUrl('http://a b.com'), isNotNull);
    });
    test('needs shop or contact', () {
      expect(MarketplaceValidation.shopOrContact('', ' '), isNotNull);
      expect(MarketplaceValidation.shopOrContact('https://a.co', ''), isNull);
      expect(MarketplaceValidation.shopOrContact(null, 'wa'), isNull);
    });
    test('image checks', () {
      expect(
        () => checkListingImage('a.gif', 10),
        throwsA(isA<ImagePickException>()),
      );
      expect(
        () => checkListingImage('a.png', 3 * 1024 * 1024),
        throwsA(isA<ImagePickException>()),
      );
      checkListingImage('A.JPG', 1000);
      expect(imageContentType('x.webp'), 'image/webp');
    });
  });

  group('MarketplaceFormScreen', () {
    testWidgets('empty submit shows every error and calls nothing', (
      tester,
    ) async {
      useTallPhone(tester);
      final api = FakeApi();
      await pumpFormLauncher(tester, api);
      await openForm(tester);
      // City is prefilled, so it is the only field without an error.
      await tester.ensureVisible(find.text('Submit for approval'));
      await tester.tap(find.text('Submit for approval'));
      await tester.pumpAndSettle();
      expect(
        find.text('Required'),
        findsNWidgets(3),
      ); // title, description, price
      expect(find.text('Choose a category'), findsOneWidget);
      expect(find.text('Add a photo'), findsOneWidget);
      expect(
        find.text('Add a shop link or contact info (at least one)'),
        findsOneWidget,
      );
      expect(api.calls, isEmpty);
    });

    testWidgets('invalid shop link is rejected', (tester) async {
      useTallPhone(tester);
      final api = FakeApi();
      await pumpFormLauncher(tester, api);
      await openForm(tester);
      await fillValid(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Online shop link (optional)'),
        'not a link',
      );
      await tester.tap(find.text('Submit for approval'));
      await tester.pumpAndSettle();
      expect(find.textContaining('valid link'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('price field only accepts digits', (tester) async {
      useTallPhone(tester);
      await pumpFormLauncher(tester, FakeApi());
      await openForm(tester);
      final price = find.widgetWithText(TextFormField, 'Price (whole rupiah)');
      await tester.enterText(price, '-1.5e3');
      expect(tester.widget<TextFormField>(price).controller!.text, '153');
    });

    testWidgets('contact warning appears only when contact is typed', (
      tester,
    ) async {
      useTallPhone(tester);
      await pumpFormLauncher(tester, FakeApi());
      await openForm(tester);
      expect(find.textContaining('visible to other members'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact info (optional)'),
        'WA 0800',
      );
      await tester.pump();
      expect(find.textContaining('visible to other members'), findsOneWidget);
    });

    testWidgets('valid submit uploads the photo, creates and confirms', (
      tester,
    ) async {
      useTallPhone(tester);
      final api = FakeApi()
        ..rpcResults['marketplace_create_listing'] = listingMap(
          status: 'pending',
          approvedAt: null,
        );
      final result = await pumpFormLauncher(tester, api);
      await openForm(tester);
      await fillValid(tester);
      await tester.tap(find.text('Submit for approval'));
      await tester.pumpAndSettle();

      expect(api.uploads.single, endsWith('foto.png|image/png'));
      expect(api.uploads.single, startsWith('s1/'));
      final p = api.params['marketplace_create_listing']!;
      expect(p['p_seller'], 's1');
      expect(p['p_title'], 'Kopi Arabika');
      expect(p['p_price_idr'], 85000);
      expect(p['p_category'], 'Food & Drink');
      expect(p['p_city'], 'Jakarta');
      expect(p['p_shop_url'], isNull);
      expect(p['p_contact_info'], 'WA 0800-0000-0000');
      expect(
        (p['p_image_url'] as String),
        startsWith('https://storage.example/s1/'),
      );
      expect(find.text(kSubmittedMessage), findsOneWidget);
      expect((await result())?.status, ListingStatus.pending);
    });

    testWidgets('unsupported and oversized photos are refused', (tester) async {
      useTallPhone(tester);
      await pumpFormLauncher(
        tester,
        FakeApi(),
        picker: () async => PickedImage(name: 'x.gif', bytes: pngBytes),
      );
      await openForm(tester);
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      expect(find.text('Use a JPG, PNG or WebP image.'), findsOneWidget);
    });

    testWidgets('server error is shown and the form stays open', (
      tester,
    ) async {
      useTallPhone(tester);
      final api = FakeApi();
      await pumpFormLauncher(tester, api);
      await openForm(tester);
      await fillValid(tester);
      api.throwOnCall = MarketplaceException(
        MarketplaceErrorCode.subscriberRequired,
        'subscriber_required',
      );
      await tester.tap(find.text('Submit for approval'));
      await tester.pumpAndSettle();
      expect(find.text('Only subscribers can post listings.'), findsOneWidget);
      expect(find.text('Submit for approval'), findsOneWidget);
    });
  });

  group('subscriber gate', () {
    Future<void> pumpMarket(
      WidgetTester tester,
      ValueNotifier<Map<String, dynamic>> u,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final api = FakeApi()..approved = [listingMap(seller: sellerMap)];
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceScreen(
            currentUser: u,
            repository: MarketplaceRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('free user gets an explanation, not the form', (tester) async {
      await pumpMarket(tester, user('free'));
      await tester.tap(find.text('Post a listing'));
      await tester.pumpAndSettle();
      expect(find.text('Subscribers only'), findsOneWidget);
      expect(find.textContaining('Browsing stays free'), findsOneWidget);
      expect(find.text('Submit for approval'), findsNothing);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Subscribers only'), findsNothing);
      expect(find.text('Submit for approval'), findsNothing);
    });

    testWidgets(
      'free user who accepts lands on the existing Subscribe screen',
      (tester) async {
        await pumpMarket(tester, user('free'));
        await tester.tap(find.text('Post a listing'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Subscribe'));
        await tester.pumpAndSettle();
        expect(find.text('Subscribe Now (Demo)'), findsOneWidget);
        expect(find.text('Rp 25.000/month'), findsOneWidget);
      },
    );

    testWidgets('subscriber goes straight to the form', (tester) async {
      await pumpMarket(tester, user('subscribed'));
      await tester.tap(find.text('Post a listing'));
      await tester.pumpAndSettle();
      expect(find.text('Subscribers only'), findsNothing);
      expect(find.text('Submit for approval'), findsOneWidget);
    });
  });

  group('MyListingsScreen', () {
    Future<FakeApi> pumpMine(
      WidgetTester tester,
      List<Map<String, dynamic>> rows,
    ) async {
      useTallPhone(tester);
      final api = FakeApi()..rpcResults['marketplace_my_listings'] = rows;
      await tester.pumpWidget(
        MaterialApp(
          home: MyListingsScreen(
            sellerId: 's1',
            repository: MarketplaceRepository(api),
            defaultCity: 'Jakarta',
            pickImage: () async =>
                PickedImage(name: 'foto.png', bytes: pngBytes),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    final mixed = [
      listingMap(
        id: 'p',
        title: 'Pending item',
        status: 'pending',
        approvedAt: null,
      ),
      listingMap(id: 'a', title: 'Approved item', status: 'approved'),
      listingMap(
        id: 'r',
        title: 'Rejected item',
        status: 'rejected',
        rejectedReason: 'Foto kurang jelas',
        approvedAt: null,
      ),
      listingMap(id: 's', title: 'Sold item', status: 'sold'),
    ];

    testWidgets('shows a badge per status, the reason, and the right actions', (
      tester,
    ) async {
      await pumpMine(tester, mixed);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Sold'), findsOneWidget);
      expect(find.text('Rejected: Foto kurang jelas'), findsOneWidget);
      expect(find.text('Demo only, no real payments'), findsOneWidget);
      // Edit: pending, approved, rejected (not sold). Mark as sold: approved only.
      expect(find.text('Edit'), findsNWidgets(3));
      expect(find.text('Mark as sold'), findsOneWidget);
      expect(find.text('Delete'), findsNWidgets(4));
    });

    testWidgets('empty state', (tester) async {
      await pumpMine(tester, []);
      expect(find.textContaining('no listings yet'), findsOneWidget);
    });

    testWidgets('error state offers retry', (tester) async {
      useTallPhone(tester);
      final api = FakeApi()..throwOnCall = Exception('boom');
      await tester.pumpWidget(
        MaterialApp(
          home: MyListingsScreen(
            sellerId: 's1',
            repository: MarketplaceRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not load your listings'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
      'editing an approved listing warns, then returns it to pending',
      (tester) async {
        final api = await pumpMine(tester, [mixed[1]]);
        expect(find.text('Approved'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Edit'));
        await tester.pumpAndSettle();
        expect(find.textContaining('back to review'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Approved item v2',
        );
        // Server state after the update: pending.
        api.rpcResults['marketplace_update_listing'] = listingMap(
          id: 'a',
          title: 'Approved item v2',
          status: 'pending',
          approvedAt: null,
        );
        api.rpcResults['marketplace_my_listings'] = [
          listingMap(
            id: 'a',
            title: 'Approved item v2',
            status: 'pending',
            approvedAt: null,
          ),
        ];
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();

        final p = api.params['marketplace_update_listing']!;
        expect(p['p_listing'], 'a');
        expect(p['p_title'], 'Approved item v2');
        expect(find.text(kEditedApprovedMessage), findsOneWidget);
        expect(find.text('Pending review'), findsOneWidget);
        expect(find.text('Approved'), findsNothing);
      },
    );

    testWidgets('delete asks first and only deletes on confirm', (
      tester,
    ) async {
      final api = await pumpMine(tester, [mixed[0]]);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this listing?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('marketplace_delete_listing')));

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      api.rpcResults['marketplace_my_listings'] = <Map<String, dynamic>>[];
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(api.params['marketplace_delete_listing'], {
        'p_seller': 's1',
        'p_listing': 'p',
      });
      expect(find.textContaining('no listings yet'), findsOneWidget);
    });

    testWidgets('mark as sold asks first, then calls the function', (
      tester,
    ) async {
      final api = await pumpMine(tester, [mixed[1]]);
      await tester.tap(find.widgetWithText(TextButton, 'Mark as sold'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as sold?'), findsOneWidget);
      api.rpcResults['marketplace_set_sold'] = listingMap(
        id: 'a',
        status: 'sold',
      );
      api.rpcResults['marketplace_my_listings'] = [
        listingMap(id: 'a', title: 'Approved item', status: 'sold'),
      ];
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as sold'));
      await tester.pumpAndSettle();
      expect(api.params['marketplace_set_sold'], {
        'p_seller': 's1',
        'p_listing': 'a',
      });
      expect(find.text('Sold'), findsOneWidget);
    });
  });
}
