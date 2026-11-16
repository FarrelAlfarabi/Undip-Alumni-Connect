import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/platform/breakpoints.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/widgets/responsive_list.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_marketplace_api.dart';

void _size(WidgetTester t, double w, [double h = 900]) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _pumpList(WidgetTester t, double width) async {
  _size(t, width);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ResponsiveListView(
          padding: const EdgeInsets.all(16),
          minTileWidth: 280,
          itemCount: 7,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) =>
              SizedBox(key: Key('item-$i'), height: 60 + i * 5.0),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('columns for a width', () {
    test('phones get one column', () {
      expect(columnsFor(390 - 32, minTileWidth: 280), 1);
      expect(columnsFor(360 - 32, minTileWidth: 280), 1);
    });
    test('wider screens get more, up to the cap', () {
      expect(columnsFor(720 - 32, minTileWidth: 280), 2);
      expect(columnsFor(960 - 32, minTileWidth: 280), 3);
      expect(columnsFor(1200 - 32, minTileWidth: 280), 3);
      expect(columnsFor(1200 - 32, minTileWidth: 280, maxColumns: 4), 4);
    });
  });

  group('ResponsiveListView', () {
    testWidgets('390: one column, full width, same as a plain list', (t) async {
      await _pumpList(t, 390);
      expect(t.getSize(find.byKey(const Key('item-0'))).width, 358);
      expect(
        t.getTopLeft(find.byKey(const Key('item-1'))).dy,
        greaterThan(t.getBottomLeft(find.byKey(const Key('item-0'))).dy),
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('768: two columns side by side', (t) async {
      await _pumpList(t, 768);
      final a = find.byKey(const Key('item-0'));
      final b = find.byKey(const Key('item-1'));
      expect(t.getTopLeft(a).dy, t.getTopLeft(b).dy);
      expect(t.getTopLeft(b).dx, greaterThan(t.getTopRight(a).dx));
      expect(t.takeException(), isNull);
    });

    testWidgets('1280: three columns, every item shown once', (t) async {
      await _pumpList(t, 1280);
      final a = find.byKey(const Key('item-0'));
      final c = find.byKey(const Key('item-2'));
      expect(t.getTopLeft(a).dy, t.getTopLeft(c).dy);
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(Key('item-$i')), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  });

  group('Admin home', () {
    Future<void> pumpAdmin(WidgetTester t, double w) async {
      _size(t, w, 1000);
      await t.pumpWidget(
        MaterialApp(
          home: AdminScreen(
            adminId: 'me',
            adminRepository: AdminRepository(FakeAdminApi()),
            marketplaceRepository: MarketplaceRepository(FakeApi()),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('390: one card per row, as before', (t) async {
      await pumpAdmin(t, 390);
      final first = find.byKey(const Key('admin-businesses'));
      expect(t.getSize(first).width, 358);
      expect(t.takeException(), isNull);
    });

    testWidgets('1280 inside the desktop column: cards side by side', (
      t,
    ) async {
      await pumpAdmin(t, 960);
      final a = find.byKey(const Key('admin-reports'));
      final b = find.byKey(const Key('admin-feedback'));
      expect(t.getTopLeft(a).dy, t.getTopLeft(b).dy);
      expect(t.takeException(), isNull);
    });
  });

  group('wide screens', () {
    test('very wide screens get a wider column', () {
      expect(shellContentWidth(1280), 960);
      expect(shellContentWidth(1920), 1200);
      expect(shellContentWidth(768), 720);
      expect(shellContentWidth(390), double.infinity);
    });

    test('lists that grow into columns on wide screens', () {
      for (final f in [
        'lib/screens/admin_screen.dart',
        'lib/screens/directory_screen.dart',
        'lib/screens/marketplace_screen.dart',
        'lib/screens/business_directory_screen.dart',
        'lib/screens/job_board_screen.dart',
      ]) {
        expect(
          File(f).readAsStringSync(),
          contains('ResponsiveListView'),
          reason: f,
        );
      }
    });
  });
}
