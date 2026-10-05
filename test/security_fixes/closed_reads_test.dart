import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/notification_repository.dart';
import 'package:undip_alumni_connect/screens/notifications_screen.dart';

/// 20261005100000_close_anon_reads.sql closes email_log and the chat tables to
/// the anon key and moves notifications behind three functions. The app must
/// not depend on any of them.
class _EmptyApi implements NotificationApi {
  @override
  Future<List<Map<String, dynamic>>> list(String recipientId) async => [];

  @override
  Future<int> unreadCount(String recipientId) async => 0;

  @override
  Future<void> markAllRead(String recipientId) async {}

  @override
  Future<Map<String, dynamic>?> job(String jobId) async => null;
}

void main() {
  testWidgets('Notifications has no simulated-email button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          currentUser: ValueNotifier({'id': 'me', 'email': 'me@example.com'}),
          repository: NotificationRepository(_EmptyApi()),
          buildPage: (d, n, u, job) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Emails (simulated)'), findsNothing);
    expect(find.byIcon(Icons.mail_outline), findsNothing);
    expect(find.text('Notifications'), findsOneWidget);
  });

  test('the simulated email screen and its table are gone from the app', () {
    expect(File('lib/screens/email_log_screen.dart').existsSync(), isFalse);
    final offenders = <String>[];
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      if (f.readAsStringSync().contains('email_log')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });

  test('notifications are read and marked through the three functions', () {
    final src = File('lib/data/notification_repository.dart')
        .readAsStringSync();
    expect(RegExp(r"from\(\s*'notifications'").hasMatch(src), isFalse);
    expect(RegExp(r"rpc\(\s*'notifications_list'").hasMatch(src), isTrue);
    expect(
      RegExp(r"rpc\(\s*'notifications_unread_count'").hasMatch(src),
      isTrue,
    );
    expect(RegExp(r"rpc\(\s*'notifications_mark_read'").hasMatch(src), isTrue);
  });
}
