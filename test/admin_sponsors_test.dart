import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_image_picker.dart';
import 'package:undip_alumni_connect/data/sponsor.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/admin_sponsors_screen.dart';
import 'package:undip_alumni_connect/screens/photo_adjust_screen.dart';

import 'support/fake_admin_api.dart';

Map<String, dynamic> row(
  String id,
  String name, {
  bool active = true,
  int rank = 1,
  String? ends,
}) => {
  'id': id,
  'name': name,
  'image_url':
      'https://x.example/storage/v1/object/public/sponsor-images/$id.jpg',
  'link_url': 'https://$id.example.com',
  'starts_on': '2026-11-01',
  'ends_on': ends,
  'rank': rank,
  'active': active,
  'views': 120,
  'taps': 7,
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('repository', () {
    test('list parses rows, hidden ones too', () async {
      final api = FakeAdminApi()
        ..results['admin_sponsor_list'] = [
          row('a', 'Bank A', ends: '2026-12-31'),
          row('b', 'Toko B', active: false),
        ];
      final list = await AdminRepository(api).sponsors('me');
      expect(api.params['admin_sponsor_list'], {'p_admin': 'me'});
      expect(list.map((s) => s.name), ['Bank A', 'Toko B']);
      expect(list.first.endsOn, DateTime(2026, 12, 31));
      expect(list.last.endsOn, isNull);
      expect(list.last.active, isFalse);
      expect(list.first.views, 120);
      expect(list.first.taps, 7);
    });

    test('save sends trimmed text and plain dates', () async {
      final api = FakeAdminApi()..results['admin_sponsor_save'] = 'new1';
      final id = await AdminRepository(api).saveSponsor(
        'me',
        name: '  Bank A ',
        imageUrl: 'https://x/y.jpg',
        linkUrl: ' https://a.example.com ',
        startsOn: DateTime(2026, 11, 1),
        endsOn: null,
        rank: 2,
        active: true,
      );
      expect(id, 'new1');
      expect(api.params['admin_sponsor_save'], {
        'p_admin': 'me',
        'p_id': null,
        'p_name': 'Bank A',
        'p_image_url': 'https://x/y.jpg',
        'p_link_url': 'https://a.example.com',
        'p_starts_on': '2026-11-01',
        'p_ends_on': null,
        'p_rank': 2,
        'p_active': true,
      });
    });

    test('delete sends the id', () async {
      final api = FakeAdminApi();
      await AdminRepository(api).deleteSponsor('me', 'a');
      expect(api.params['admin_sponsor_delete'], {
        'p_admin': 'me',
        'p_id': 'a',
      });
    });

    test('Sponsor.isLive follows dates and the switch', () {
      final today = DateTime(2026, 11, 10);
      Sponsor s({DateTime? from, DateTime? to, bool active = true}) => Sponsor(
        id: 'a',
        name: 'A',
        imageUrl: 'https://x/y.jpg',
        linkUrl: 'https://a.example.com',
        startsOn: from,
        endsOn: to,
        rank: 1,
        active: active,
      );
      expect(s().isLive(today), isTrue);
      expect(s(from: DateTime(2026, 11, 11)).isLive(today), isFalse);
      expect(s(to: DateTime(2026, 11, 9)).isLive(today), isFalse);
      expect(s(to: DateTime(2026, 11, 10)).isLive(today), isTrue);
      expect(s(active: false).isLive(today), isFalse);
    });
  });

  group('screens', () {
    setUp(() => PhotoAdjust.enabled = false);
    tearDown(() => PhotoAdjust.enabled = true);

    Future<FakeAdminApi> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows, {
      ImagePickerFn? pick,
    }) async {
      phone(tester);
      final api = FakeAdminApi()
        ..results['admin_sponsor_list'] = rows
        ..results['admin_sponsor_save'] = 'new1';
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSponsorsScreen(
            adminId: 'me',
            repository: AdminRepository(api),
            pickImage:
                pick ??
                () async => PickedImage(name: 'a.jpg', bytes: Uint8List(3)),
            uploadImage: (_) async => 'https://x/new.jpg',
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('Admin home lists Sponsor', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminScreen(
            adminId: 'me',
            adminRepository: AdminRepository(FakeAdminApi()),
          ),
        ),
      );
      expect(find.byKey(const Key('admin-sponsors')), findsOneWidget);
    });

    testWidgets('list shows several sponsors and marks hidden ones', (
      tester,
    ) async {
      await pump(tester, [
        row('a', 'Bank A'),
        row('b', 'Toko B', active: false),
      ]);
      expect(find.byKey(const Key('sponsor-admin-a')), findsOneWidget);
      expect(find.byKey(const Key('sponsor-admin-b')), findsOneWidget);
      expect(find.textContaining('Disembunyikan'), findsOneWidget);
      expect(find.textContaining('120 dilihat'), findsNWidgets(2));
      expect(find.textContaining('7 diketuk'), findsNWidgets(2));
    });

    testWidgets('empty form is refused without a call', (tester) async {
      final api = await pump(tester, []);
      await tester.tap(find.byKey(const Key('sponsor-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sponsor-save')));
      await tester.pumpAndSettle();
      expect(find.text('Isi nama sponsor.'), findsOneWidget);
      expect(find.text('Isi tautan sponsor.'), findsOneWidget);
      expect(find.text('Pilih gambar sponsor.'), findsOneWidget);
      expect(api.calls.contains('admin_sponsor_save'), isFalse);
    });

    testWidgets('the link must be https', (tester) async {
      final api = await pump(tester, []);
      await tester.tap(find.byKey(const Key('sponsor-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('sponsor-name')), 'Bank A');
      await tester.enterText(
        find.byKey(const Key('sponsor-link')),
        'http://a.example.com',
      );
      await tester.tap(find.byKey(const Key('sponsor-save')));
      await tester.pumpAndSettle();
      expect(find.text('Tautan harus diawali https://'), findsOneWidget);
      expect(api.calls.contains('admin_sponsor_save'), isFalse);
    });

    testWidgets('adding a second sponsor uploads the image and saves', (
      tester,
    ) async {
      final api = await pump(tester, [row('a', 'Bank A')]);
      await tester.tap(find.byKey(const Key('sponsor-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('sponsor-name')), 'Toko B');
      await tester.enterText(
        find.byKey(const Key('sponsor-link')),
        'https://b.example.com',
      );
      await tester.tap(find.byKey(const Key('sponsor-choose-image')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sponsor-save')));
      await tester.pumpAndSettle();
      final p = api.params['admin_sponsor_save']!;
      expect(p['p_id'], isNull);
      expect(p['p_name'], 'Toko B');
      expect(p['p_image_url'], 'https://x/new.jpg');
      expect(p['p_link_url'], 'https://b.example.com');
      expect(p['p_active'], true);
      expect(api.calls.where((c) => c == 'admin_sponsor_list').length, 2);
    });

    testWidgets('editing keeps the old image and can hide the sponsor', (
      tester,
    ) async {
      final api = await pump(tester, [row('a', 'Bank A')]);
      await tester.tap(find.byKey(const Key('sponsor-admin-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sponsor-active')));
      await tester.tap(find.byKey(const Key('sponsor-save')));
      await tester.pumpAndSettle();
      final p = api.params['admin_sponsor_save']!;
      expect(p['p_id'], 'a');
      expect(p['p_image_url'], contains('sponsor-images/a.jpg'));
      expect(p['p_active'], false);
    });

    testWidgets('delete asks first, then calls', (tester) async {
      final api = await pump(tester, [row('a', 'Bank A')]);
      await tester.tap(find.byKey(const Key('sponsor-admin-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sponsor-delete')));
      await tester.pumpAndSettle();
      expect(api.calls.contains('admin_sponsor_delete'), isFalse);
      await tester.tap(find.byKey(const Key('sponsor-delete-confirm')));
      await tester.pumpAndSettle();
      expect(api.params['admin_sponsor_delete'], {
        'p_admin': 'me',
        'p_id': 'a',
      });
    });
  });
}
