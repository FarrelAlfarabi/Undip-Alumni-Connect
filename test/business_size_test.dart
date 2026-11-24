// Business size (24 Nov 2026): Mikro, Kecil, Menengah, Besar shown on the
// business card and as a filter in the business list. The size is the band
// the admin approved (UMKM bands, PP 7/2021).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/business_directory_screen.dart';
import 'package:undip_alumni_connect/widgets/filter_dropdown.dart';

import 'support/fake_business_api.dart';

void main() {
  test('Indonesian UMKM names', () {
    expect(BusinessBand.micro.sizeLabel, 'Mikro');
    expect(BusinessBand.small.sizeLabel, 'Kecil');
    expect(BusinessBand.medium.sizeLabel, 'Menengah');
    expect(BusinessBand.large.sizeLabel, 'Besar');
  });

  test('filter by size', () {
    final all = [
      Business.fromMap(
        businessMap(id: 'a', status: 'approved', approvedBand: 'micro'),
      ),
      Business.fromMap(
        businessMap(id: 'b', status: 'approved', approvedBand: 'medium'),
      ),
      Business.fromMap(businessMap(id: 'c', status: 'approved')),
    ];
    List<String> ids(String size) => applyBusinessFilters(
      all,
      query: '',
      category: kAllFilter,
      size: size,
    ).map((b) => b.id).toList();
    expect(ids(kAllFilter), ['a', 'b', 'c']);
    expect(ids('Mikro'), ['a']);
    expect(ids('Menengah'), ['b']);
    expect(ids('Besar'), isEmpty);
  });

  testWidgets('card shows the size and the list filters by it', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeBusinessApi()
      ..results['business_directory'] = [
        businessMap(
          id: 'a',
          name: 'Kopi Ahmad',
          status: 'approved',
          approvedBand: 'micro',
        ),
        businessMap(
          id: 'b',
          name: 'Batik Clara',
          status: 'approved',
          approvedBand: 'small',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessDirectoryScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          repository: BusinessRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('business-size-a')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('business-size-a')),
        matching: find.text('Mikro'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('business-size-filter')), findsOneWidget);
    await tester.tap(find.byKey(const Key('business-size-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kecil').last);
    await tester.pumpAndSettle();
    expect(find.text('Batik Clara'), findsOneWidget);
    expect(find.text('Kopi Ahmad'), findsNothing);
    expect(find.byType(FilterDropdown), findsWidgets);
  });
}
