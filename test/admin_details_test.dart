// Admin Bisnis and Marketplace lists get a Detail button (24 Nov 2026): the
// admin opens one business or product and sees everything about it, with
// links that open.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/admin_detail_screens.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_admin_screen.dart';
import 'package:undip_alumni_connect/widgets/safe_link_chip.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';
import 'support/fake_marketplace_api.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('admin opens a business from the Bisnis list', (tester) async {
    phone(tester);
    final api = FakeAdminApi()
      ..results['admin_businesses_list'] = [
        businessMap(
          description: 'Kopi dari Semarang, sangrai sendiri setiap pagi',
          website: 'https://kopiahmad.id',
          ownerName: 'Ahmad Ramadhan',
          requestedBand: 'micro',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: AdminBusinessesScreen(
          adminId: 'me',
          repository: AdminRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('business-detail-b1')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminBusinessDetailScreen), findsOneWidget);
    expect(find.text('Detail usaha'), findsOneWidget);
    expect(
      find.text('Kopi dari Semarang, sangrai sendiri setiap pagi'),
      findsOneWidget,
    );
    expect(find.textContaining('Ahmad Ramadhan'), findsWidgets);
    expect(find.textContaining('Mikro'), findsWidgets);
    expect(find.byType(SafeLinkChip), findsNWidgets(2));
    // Back returns to the list.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AdminBusinessesScreen), findsOneWidget);
  });

  Future<FakeApi> pumpMarket(WidgetTester tester) async {
    phone(tester);
    final api = FakeApi()
      ..rpcResults['marketplace_admin_pending'] = [
        listingMap(id: 'q1', title: 'Batik Tulis', status: 'pending'),
      ]
      ..rpcResults['marketplace_report_details'] = <dynamic>[]
      ..approved = [
        listingMap(
          id: 'p1',
          title: 'Kopi Arabika',
          shopUrl: 'https://tokopedia.com/kopi',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceAdminScreen(
          adminId: 'admin',
          repository: MarketplaceRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('admin opens a product from the Products tab', (tester) async {
    await pumpMarket(tester);
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product-detail-p1')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminProductDetailScreen), findsOneWidget);
    expect(find.text('Detail produk'), findsOneWidget);
    expect(find.text('Kopi Arabika'), findsOneWidget);
    expect(find.text('Sangrai medium'), findsOneWidget);
    expect(find.textContaining('Semarang'), findsWidgets);
    expect(find.textContaining('WA 0800-0000-0000'), findsOneWidget);
    expect(find.byType(SafeLinkChip), findsOneWidget);
  });

  testWidgets('admin opens a product waiting for review', (tester) async {
    await pumpMarket(tester);
    await tester.tap(find.byKey(const Key('review-detail-q1')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminProductDetailScreen), findsOneWidget);
    expect(find.text('Batik Tulis'), findsOneWidget);
  });
}
