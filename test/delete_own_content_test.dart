import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/screens/admin_announcements_screen.dart';
import 'package:undip_alumni_connect/screens/my_businesses_screen.dart';
import 'package:undip_alumni_connect/screens/my_job_postings_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('business delete sends owner and business', () async {
    final api = FakeBusinessApi();
    await BusinessRepository(api).delete('me', 'b1');
    expect(api.params['business_delete'], {'p_owner': 'me', 'p_business': 'b1'});
  });

  test('announcement delete sends admin and id', () async {
    final api = FakeAdminApi();
    await AdminRepository(api).deleteAnnouncement('me', 'a1');
    expect(api.params['admin_announcement_delete'], {
      'p_admin': 'me',
      'p_id': 'a1',
    });
  });

  testWidgets('owner deletes a business after confirming', (tester) async {
    phone(tester);
    final api = FakeBusinessApi()
      ..results['business_my'] = [
        businessMap(id: 'c', name: 'Approved Co', status: 'approved'),
      ]
      ..results['business_my_usage'] = [];
    await tester.pumpWidget(
      MaterialApp(
        home: MyBusinessesScreen(
          ownerId: 'me',
          repository: BusinessRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-c')));
    await tester.pumpAndSettle();
    expect(api.calls.contains('business_delete'), isFalse);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(api.params['business_delete'], {'p_owner': 'me', 'p_business': 'c'});
  });

  testWidgets('cancel keeps the business', (tester) async {
    phone(tester);
    final api = FakeBusinessApi()
      ..results['business_my'] = [businessMap(id: 'c')]
      ..results['business_my_usage'] = [];
    await tester.pumpWidget(
      MaterialApp(
        home: MyBusinessesScreen(
          ownerId: 'me',
          repository: BusinessRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-c')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(api.calls.contains('business_delete'), isFalse);
  });

  testWidgets('poster deletes a job after confirming', (tester) async {
    phone(tester);
    final deleted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MyJobPostingsScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          fetch: (id) async => [
            {'id': 'j1', 'title': 'Analyst', 'company': 'Bank X'},
          ],
          deleteJob: (me, id) async => deleted.add('$me/$id'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-job-j1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(deleted, ['me/j1']);
  });

  testWidgets('admin deletes an announcement after confirming', (tester) async {
    phone(tester);
    final api = FakeAdminApi()
      ..results['admin_announcement_list'] = [
        {
          'id': 'a1',
          'title': 'Reuni',
          'body': 'Isi',
          'posted_by_name': 'Gilang',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: AdminAnnouncementsScreen(
          adminId: 'me',
          repository: AdminRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-announcement-a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(api.params['admin_announcement_delete'], {
      'p_admin': 'me',
      'p_id': 'a1',
    });
  });
}
