import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/data/notification_repository.dart';
import 'package:undip_alumni_connect/models/app_notification.dart';
import 'package:undip_alumni_connect/screens/home_screen.dart';
import 'package:undip_alumni_connect/screens/notifications_screen.dart';

import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

Map<String, dynamic> note({
  String id = 'n1',
  String title = 'New request to contact',
  String body = 'Siti would like to contact you.',
  String? type = 'contact_request_received',
  String? targetType = 'contact_request',
  String? targetId = 'r1',
  String? jobPostId,
  String? readAt,
  String createdAt = '2026-10-02T08:00:00+00:00',
}) => {
  'id': id,
  'title': title,
  'body': body,
  'type': type,
  'target_type': targetType,
  'target_id': targetId,
  'job_post_id': jobPostId,
  'read_at': readAt,
  'created_at': createdAt,
};

class FakeNotificationApi implements NotificationApi {
  FakeNotificationApi(this.rows);
  List<Map<String, dynamic>> rows;
  Object? listError;
  Object? markError;
  int markCalls = 0;
  int unread = 0;
  Map<String, dynamic>? jobRow;
  final jobCalls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> list(String recipientId) async {
    if (listError != null) throw listError!;
    return rows;
  }

  @override
  Future<int> unreadCount(String recipientId) async => unread;

  @override
  Future<void> markAllRead(String recipientId) async {
    markCalls++;
    if (markError != null) throw markError!;
  }

  @override
  Future<Map<String, dynamic>?> job(String jobId) async {
    jobCalls.add(jobId);
    return jobRow;
  }
}

final me = ValueNotifier<Map<String, dynamic>>({
  'id': 'me',
  'name': 'Me',
  'email': 'me@example.com',
});

Widget destPage(
  NotificationDestination d,
  AppNotification n,
  ValueNotifier<Map<String, dynamic>> u,
  Map<String, dynamic>? job,
) => MarkerPage('DEST ${d.name}${job != null ? ' ${job['id']}' : ''}');

void main() {
  group('model and repository', () {
    test('fromMap reads the typed columns, old rows have none', () {
      final n = AppNotification.fromMap(note());
      expect(n.type, 'contact_request_received');
      expect(n.targetId, 'r1');
      expect(n.isUnread, isTrue);
      final old = AppNotification.fromMap(
        note(type: null, targetType: null, targetId: null, jobPostId: 'j1'),
      );
      expect(old.type, isNull);
      expect(old.jobPostId, 'j1');
    });

    test('newest first', () async {
      final api = FakeNotificationApi([
        note(id: 'a', createdAt: '2026-10-01T00:00:00Z'),
        note(id: 'c', createdAt: '2026-10-03T00:00:00Z'),
        note(id: 'b', createdAt: '2026-10-02T00:00:00Z'),
      ]);
      final list = await NotificationRepository(api).list('me');
      expect(list.map((n) => n.id), ['c', 'b', 'a']);
    });

    test('anything that links to chat is hidden while chat is off', () async {
      final api = FakeNotificationApi([
        note(id: 'ok'),
        note(id: 'chat1', type: 'chat_message', targetType: 'conversation'),
        note(id: 'chat2', type: null, targetType: 'chat'),
      ]);
      expect(
        (await NotificationRepository(
          api,
        ).list('me', chat: false)).map((n) => n.id),
        ['ok'],
      );
      expect(
        (await NotificationRepository(api).list('me', chat: true)).length,
        3,
      );
    });

    test('the app never inserts a notification', () {
      final hits = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final text = f.readAsStringSync();
        if (RegExp(r"""from\(\s*['"]notifications['"]\s*\)\s*\.insert""")
                .hasMatch(text) ||
            RegExp(r"""notifications['"]\)[\s\S]{0,40}\.upsert""")
                .hasMatch(text)) {
          hits.add(f.path);
        }
      }
      expect(hits, isEmpty);
      // The API seam has no insert method at all.
      final src = File('lib/data/notification_repository.dart')
          .readAsStringSync();
      expect(src.contains('.insert('), isFalse);
    });
  });

  group('destinations', () {
    NotificationDestination d(Map<String, dynamic> m) =>
        destinationOf(AppNotification.fromMap(m));

    test('each type goes to the right place', () {
      expect(d(note()), NotificationDestination.requestsReceived);
      expect(
        d(note(type: 'contact_request_accepted')),
        NotificationDestination.requestsSent,
      );
      for (final t in [
        'business_approved',
        'business_rejected',
        'business_suspended',
        'business_restored',
      ]) {
        expect(
          d(note(type: t, targetType: 'business')),
          NotificationDestination.myBusinesses,
        );
      }
      expect(
        d(note(type: 'content_hidden', targetType: 'business')),
        NotificationDestination.myBusinesses,
      );
      expect(
        d(note(type: 'content_hidden', targetType: 'product')),
        NotificationDestination.myListings,
      );
      expect(
        d(note(type: 'content_hidden', targetType: 'job')),
        NotificationDestination.hiddenJobInfo,
      );
      expect(
        d(note(type: 'report_new', targetType: 'job')),
        NotificationDestination.adminReports,
      );
      expect(
        d(note(type: 'business_pending', targetType: 'business')),
        NotificationDestination.adminBusinesses,
      );
      expect(
        d(note(type: 'job_application', targetType: 'job', targetId: 'j1')),
        NotificationDestination.jobApplicants,
      );
      expect(
        d(note(type: null, targetType: null, targetId: null, jobPostId: 'j1')),
        NotificationDestination.jobApplicants,
      );
      expect(
        d(note(type: 'something_new', targetType: null, targetId: null)),
        NotificationDestination.none,
      );
    });
  });

  group('Notifications screen', () {
    Future<FakeNotificationApi> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows,
    ) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeNotificationApi(rows);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(
            currentUser: me,
            repository: NotificationRepository(api),
            buildPage: destPage,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('empty state', (tester) async {
      await pump(tester, []);
      expect(find.textContaining('No notifications yet'), findsOneWidget);
    });

    testWidgets('lists newest first and marks everything read on open, once', (
      tester,
    ) async {
      final api = await pump(tester, [
        note(
          id: 'old',
          title: 'Older one',
          createdAt: '2026-10-01T00:00:00Z',
          readAt: '2026-10-01T01:00:00Z',
        ),
        note(id: 'new', title: 'Newer one', createdAt: '2026-10-03T00:00:00Z'),
      ]);
      final titles = tester
          .widgetList<Text>(find.textContaining('one'))
          .map((t) => t.data)
          .toList();
      expect(titles, ['Newer one', 'Older one']);
      expect(api.markCalls, 1);
    });

    testWidgets('a failed mark-as-read does not hide the list', (tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeNotificationApi([note(title: 'Still here')])
        ..markError = Exception('net');
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(
            currentUser: me,
            repository: NotificationRepository(api),
            buildPage: destPage,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Still here'), findsOneWidget);
    });

    testWidgets('a failed load shows a friendly message and Try again', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeNotificationApi([])
        ..listError = Exception('SocketException: Failed host lookup');
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(
            currentUser: me,
            repository: NotificationRepository(api),
            buildPage: destPage,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      api.listError = null;
      api.rows = [note(title: 'Back again')];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Back again'), findsOneWidget);
    });

    testWidgets('tapping a request notification opens Requests', (
      tester,
    ) async {
      await pump(tester, [note()]);
      await tester.tap(find.byKey(const Key('notification-n1')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE DEST requestsReceived'), findsOneWidget);
    });

    testWidgets('accepted opens the Sent tab', (tester) async {
      await pump(tester, [note(type: 'contact_request_accepted')]);
      await tester.tap(find.byKey(const Key('notification-n1')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE DEST requestsSent'), findsOneWidget);
    });

    testWidgets('business decisions open My businesses', (tester) async {
      await pump(tester, [
        note(
          type: 'business_rejected',
          targetType: 'business',
          body: 'Reason: Link rusak',
        ),
      ]);
      await tester.tap(find.byKey(const Key('notification-n1')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE DEST myBusinesses'), findsOneWidget);
    });

    testWidgets('a hidden job shows the reason in a dialog', (tester) async {
      await pump(tester, [
        note(
          type: 'content_hidden',
          targetType: 'job',
          title: 'Hidden by an admin',
          body: 'Your job "Staff" was hidden. Reason: Palsu',
        ),
      ]);
      await tester.tap(find.byKey(const Key('notification-n1')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Reason: Palsu'), findsWidgets);
    });

    testWidgets('admin notifications open the admin screens', (tester) async {
      await pump(tester, [
        note(id: 'a', type: 'report_new', targetType: 'job'),
        note(
          id: 'b',
          type: 'business_pending',
          targetType: 'business',
          createdAt: '2026-10-01T00:00:00Z',
        ),
      ]);
      await tester.tap(find.byKey(const Key('notification-a')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE DEST adminReports'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notification-b')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE DEST adminBusinesses'), findsOneWidget);
    });

    testWidgets('job application opens the applicants when the job exists', (
      tester,
    ) async {
      final api = await pump(tester, [
        note(type: 'job_application', targetType: 'job', targetId: 'j1'),
      ]);
      api.jobRow = {'id': 'j1', 'title': 'Staff'};
      await tester.tap(find.byKey(const Key('notification-n1')));
      await tester.pumpAndSettle();
      expect(api.jobCalls, ['j1']);
      expect(find.text('PAGE DEST jobApplicants j1'), findsOneWidget);
    });

    testWidgets(
      'a gone or hidden job gives a friendly message, no new screen',
      (tester) async {
        final api = await pump(tester, [
          note(type: 'job_application', targetType: 'job', targetId: 'j1'),
        ]);
        api.jobRow = null;
        await tester.tap(find.byKey(const Key('notification-n1')));
        await tester.pumpAndSettle();
        expect(find.text(kNotificationGone), findsOneWidget);
        expect(find.textContaining('PAGE DEST'), findsNothing);
      },
    );

    testWidgets(
      'an old row that only has a job id still opens the applicants',
      (tester) async {
        final api = await pump(tester, [
          note(type: null, targetType: null, targetId: null, jobPostId: 'j9'),
        ]);
        api.jobRow = {'id': 'j9'};
        await tester.tap(find.byKey(const Key('notification-n1')));
        await tester.pumpAndSettle();
        expect(find.text('PAGE DEST jobApplicants j9'), findsOneWidget);
      },
    );
  });

  group('Home bell', () {
    Future<void> pumpHome(WidgetTester tester, int unread) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentUser: me,
            onOpenDirectory: () {},
            pages: fakePages(),
            api: FakeHomeApi(unreadNotifications: unread),
            marketplaceRepository: MarketplaceRepository(FakeApi()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('bell with the unread count', (tester) async {
      await pumpHome(tester, 4);
      final badge = tester.widget<Badge>(
        find.byKey(const Key('notifications-badge')),
      );
      expect(badge.isLabelVisible, isTrue);
      expect((badge.label as Text).data, '4');
    });

    testWidgets('no badge at zero, and the bell opens Notifications', (
      tester,
    ) async {
      await pumpHome(tester, 0);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('notifications-badge')))
            .isLabelVisible,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('home-notifications')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE Notifications'), findsOneWidget);
    });
  });
}
