import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/models/business_edit_request.dart';
import 'package:undip_alumni_connect/screens/admin_business_edits_screen.dart';
import 'package:undip_alumni_connect/screens/my_businesses_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';

Map<String, dynamic> ownerRow({
  String status = 'pending',
  String name = 'Kopi Baru',
  String? reason,
}) => {
  'id': 'r1',
  'business_id': 'b1',
  'owner_id': 'me',
  'name': name,
  'description': 'Kopi dari Semarang',
  'category': 'Food & Drink',
  'social_link': 'https://instagram.com/kopi_ahmad',
  'website_link': null,
  'is_personal': false,
  'nib': null,
  'photo_url': null,
  'status': status,
  'reject_reason': reason,
  'created_at': '2026-11-26T08:00:00+00:00',
};

Map<String, dynamic> adminRow({String? newNib, String? oldNib}) => {
  'request_id': 'r1',
  'business_id': 'b1',
  'owner_id': 'o1',
  'owner_name': 'Ahmad',
  'req_status': 'pending',
  'created_at': '2026-11-26T08:00:00+00:00',
  'new_name': 'Kopi Baru',
  'new_description': 'Deskripsi sama',
  'new_category': 'Food & Drink',
  'new_social_link': 'https://instagram.com/kopi',
  'new_website_link': null,
  'new_is_personal': false,
  'new_nib': newNib,
  'new_photo_url': null,
  'old_name': 'Kopi Lama',
  'old_description': 'Deskripsi sama',
  'old_category': 'Food & Drink',
  'old_social_link': 'https://instagram.com/kopi',
  'old_website_link': null,
  'old_is_personal': false,
  'old_nib': oldNib,
  'old_photo_url': null,
  'old_nib_verified': oldNib != null,
};

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('model', () {
    test('only changed fields are listed', () {
      final r = BusinessEditRequest.fromAdminRow(adminRow());
      final c = r.changes();
      expect(c.map((e) => e.field), ['name']);
      expect(c.single.oldText, 'Kopi Lama');
      expect(c.single.newText, 'Kopi Baru');
    });

    test('a changed NIB shows up as a change', () {
      final r = BusinessEditRequest.fromAdminRow(
        adminRow(oldNib: '1111111111111', newNib: '2222222222222'),
      );
      expect(r.changes().map((e) => e.field), contains('nib'));
      expect(r.currentNibVerified, isTrue);
    });
  });

  group('repository', () {
    test('submitEdit sends the owner, business and proposed values', () async {
      final api = FakeBusinessApi()
        ..results['business_edit_request_submit'] = ownerRow();
      final r = await BusinessRepository(api).submitEdit(
        'me',
        'b1',
        const BusinessValues(
          name: 'Kopi Baru',
          description: 'd',
          category: 'Food & Drink',
          socialLink: 'https://instagram.com/kopi_ahmad',
          nib: '1234 5678 90123',
        ),
      );
      final p = api.params['business_edit_request_submit']!;
      expect(p['p_owner'], 'me');
      expect(p['p_business'], 'b1');
      expect(p['p_name'], 'Kopi Baru');
      expect(p['p_nib'], '1234567890123');
      expect(r.isPending, isTrue);
      // Nothing that could change the band, status or the tick.
      expect(
        p.keys.any((k) => k.contains('band') || k.contains('status')),
        isFalse,
      );
      expect(api.calls, isNot(contains('business_update')));
    });

    test('no_change gets its own plain message', () async {
      final api = FakeBusinessApi()..throwOnCall = pgError('no_change');
      await expectLater(
        BusinessRepository(api).submitEdit(
          'me',
          'b1',
          const BusinessValues(name: 'N1', description: 'd', category: 'Other'),
        ),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.noChange,
          ),
        ),
      );
    });

    test('a failing request list gives none, not an error', () async {
      final api = FakeBusinessApi()..throwOnCall = Exception('x');
      expect(await BusinessRepository(api).myEdits('me'), isEmpty);
    });

    test('admin decide sends approve / reject with the reason', () async {
      final api = FakeAdminApi();
      final repo = AdminRepository(api);
      await repo.decideBusinessEdit('adm', 'r1', false, reason: 'Salah');
      expect(api.params['admin_business_edit_decide'], {
        'p_admin': 'adm',
        'p_request': 'r1',
        'p_action': 'reject',
        'p_reason': 'Salah',
      });
      await repo.decideBusinessEdit('adm', 'r1', true);
      expect(api.params['admin_business_edit_decide']!['p_action'], 'approve');
    });
  });

  group('owner screen', () {
    Future<FakeBusinessApi> pump(
      WidgetTester tester, {
      List<Map<String, dynamic>> edits = const [],
    }) async {
      tall(tester);
      final api = FakeBusinessApi()
        ..results['business_my'] = [businessMap(status: 'approved')]
        ..results['business_edit_request_my'] = edits
        ..results['business_edit_request_cancel'] = ownerRow(
          status: 'cancelled',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: MyBusinessesScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('approved business offers a change request', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('request-edit-b1')), findsOneWidget);
      expect(find.byKey(const Key('edit-pending-b1')), findsNothing);
      await tester.tap(find.byKey(const Key('request-edit-b1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-request-note')), findsOneWidget);
      expect(find.text('Kirim perubahan'), findsOneWidget);
    });

    testWidgets('a pending request shows its status and can be cancelled', (
      tester,
    ) async {
      final api = await pump(tester, edits: [ownerRow()]);
      expect(find.byKey(const Key('edit-pending-b1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('edit-cancel-b1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-edit-yes')));
      await tester.pumpAndSettle();
      expect(api.params['business_edit_request_cancel'], {
        'p_owner': 'me',
        'p_request': 'r1',
      });
    });

    testWidgets('a rejected request shows the reason', (tester) async {
      await pump(
        tester,
        edits: [ownerRow(status: 'rejected', reason: 'Nama bentrok')],
      );
      expect(find.textContaining('Nama bentrok'), findsOneWidget);
      expect(find.byKey(const Key('edit-cancel-b1')), findsNothing);
    });

    testWidgets('sending the form asks for approval, never edits directly', (
      tester,
    ) async {
      final api = await pump(tester);
      api.results['business_edit_request_submit'] = ownerRow();
      await tester.tap(find.byKey(const Key('request-edit-b1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name *'),
        'Kopi Baru',
      );
      await tester.tap(find.text('Kirim perubahan'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('business_edit_request_submit'));
      expect(api.calls, isNot(contains('business_update')));
      expect(
        api.params['business_edit_request_submit']!['p_name'],
        'Kopi Baru',
      );
    });
  });

  group('admin screen', () {
    Future<FakeAdminApi> pump(WidgetTester tester) async {
      tall(tester);
      final api = FakeAdminApi()
        ..results['admin_business_edit_requests'] = [adminRow()];
      await tester.pumpWidget(
        MaterialApp(
          home: AdminBusinessEditsScreen(
            adminId: 'adm',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('shows old and new side by side', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('old-name')), findsOneWidget);
      expect(find.text('Kopi Lama'), findsWidgets);
      expect(find.byKey(const Key('new-name')), findsOneWidget);
      expect(find.text('Kopi Baru'), findsOneWidget);
      // Unchanged fields are not listed.
      expect(find.byKey(const Key('old-description')), findsNothing);
    });

    testWidgets('approve calls the database', (tester) async {
      final api = await pump(tester);
      await tester.tap(find.byKey(const Key('edit-approve-r1')));
      await tester.pumpAndSettle();
      expect(api.params['admin_business_edit_decide']!['p_action'], 'approve');
    });

    testWidgets('reject needs a reason', (tester) async {
      final api = await pump(tester);
      await tester.tap(find.byKey(const Key('edit-reject-r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-reject-confirm')));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('admin_business_edit_decide')));
      await tester.enterText(
        find.byKey(const Key('edit-reject-reason')),
        'Nama bentrok',
      );
      await tester.tap(find.byKey(const Key('edit-reject-confirm')));
      await tester.pumpAndSettle();
      expect(api.params['admin_business_edit_decide'], {
        'p_admin': 'adm',
        'p_request': 'r1',
        'p_action': 'reject',
        'p_reason': 'Nama bentrok',
      });
    });
  });
}
