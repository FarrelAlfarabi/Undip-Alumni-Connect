import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:undip_alumni_connect/auth/login_api.dart';
import 'package:undip_alumni_connect/config/policy_config.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/screens/admin_reports_screen.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';
import 'package:undip_alumni_connect/util/friendly_error.dart';

import 'account_test.dart' show appHome, phone, withPolicyBundle;
import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart' show pgError;
import 'support/fake_lock.dart';

class _SuspendedLogin implements LoginApi {
  @override
  Future<bool> emailKnown(String email) async => true;
  @override
  Future<void> sendCode(String email) async {}
  @override
  Future<Map<String, dynamic>?> verifyCode(String email, String code) async =>
      throw pgError('account_suspended');
  @override
  bool get hasSession => false;
  @override
  Future<void> signOut() async {}
}

Map<String, dynamic> row({
  required String type,
  required String id,
  String title = 'Budi Santoso',
  bool hidden = false,
  String? hiddenReason,
}) => {
  'target_type': type,
  'target_id': id,
  'title': title,
  'owner_id': 'o',
  'owner_name': 'Budi',
  'report_count': 1,
  'reasons': hidden ? <String>[] : ['spam_or_scam'],
  'notes': <String>[],
  'last_reported': DateTime.now().toUtc().toIso8601String(),
  'is_hidden': hidden,
  'hidden_reason': hiddenReason,
};

void main() {
  group('the suspended message', () {
    test('friendlyError names the suspension and the contact address', () {
      final msg = friendlyError(pgError('account_suspended'));
      expect(msg, kSuspendedMessage);
      expect(msg.toLowerCase(), contains('suspended'));
      expect(msg, contains(kContactEmail));
      expect(msg, isNot(contains('account_suspended')));
    });

    test('other errors are unchanged', () {
      expect(friendlyError(pgError('something else')), kGenericError);
      expect(friendlyError(PostgrestException(message: 'x')), kGenericError);
    });

    testWidgets('email match: a suspended person is told, not "not found"', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        withPolicyBundle(
          MaterialApp(
            home: VerificationScreen(
              lock: makeLock(enabled: false),
              verifyEmail: (_) async => throw pgError('account_suspended'),
              homeBuilder: appHome,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), testEmail);
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(find.textContaining('suspended'), findsWidgets);
      expect(find.textContaining(kContactEmail), findsWidgets);
      expect(find.text('Something Went Wrong'), findsNothing);
    });

    testWidgets('email code: a suspended person is told, not "wrong code"', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        withPolicyBundle(
          MaterialApp(
            home: VerificationScreen(
              loginApi: _SuspendedLogin(),
              lock: makeLock(enabled: false),
              homeBuilder: appHome,
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('login-email')), testEmail);
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('login-code')), '123456');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.textContaining('suspended'), findsWidgets);
      expect(find.textContaining('wrong or has expired'), findsNothing);
    });
  });

  group('Reports: suspend user', () {
    Future<FakeAdminApi> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows,
    ) async {
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeAdminApi()..results['admin_reports_list'] = rows;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportsScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    test('only a reported person or contact request can be suspended', () {
      AdminReport r(String type) =>
          AdminReport.fromMap(row(type: type, id: 'x'));
      expect(r('profile').canSuspend, isTrue);
      expect(r('contact_request').canSuspend, isTrue);
      expect(r('job').canSuspend, isFalse);
      expect(r('product').canSuspend, isFalse);
      expect(r('business').canSuspend, isFalse);
    });

    testWidgets('a profile report has Suspend user, a job report does not', (
      tester,
    ) async {
      await pump(tester, [
        row(type: 'profile', id: 'u1'),
        row(type: 'contact_request', id: 'q1', title: 'Halo'),
        row(type: 'job', id: 'j1', title: 'Staff'),
      ]);
      expect(find.byKey(const Key('suspend-u1')), findsOneWidget);
      expect(find.byKey(const Key('suspend-q1')), findsOneWidget);
      expect(find.byKey(const Key('suspend-j1')), findsNothing);
      expect(find.text('Suspend user'), findsNWidgets(2));
    });

    testWidgets('suspending needs a reason, then sends suspend_user', (
      tester,
    ) async {
      final api = await pump(tester, [row(type: 'profile', id: 'u1')]);
      await tester.tap(find.byKey(const Key('suspend-u1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot sign in'), findsOneWidget);
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Suspend'),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('A reason is required'), findsOneWidget);
      expect(api.calls.contains('admin_reports_decide'), isFalse);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Akun palsu',
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(api.params['admin_reports_decide'], {
        'p_admin': 'me',
        'p_type': 'profile',
        'p_target': 'u1',
        'p_action': 'suspend_user',
        'p_reason': 'Akun palsu',
      });
    });

    testWidgets('cancel changes nothing', (tester) async {
      final api = await pump(tester, [row(type: 'profile', id: 'u1')]);
      await tester.tap(find.byKey(const Key('suspend-u1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls.contains('admin_reports_decide'), isFalse);
    });

    testWidgets('Hidden list: a suspended person can be let back in', (
      tester,
    ) async {
      final api = await pump(tester, []);
      api.results['admin_reports_list'] = [
        row(
          type: 'profile',
          id: 'u1',
          hidden: true,
          hiddenReason: 'Akun palsu',
        ),
      ];
      await tester.tap(find.text('Hidden'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Suspended: Akun palsu'), findsOneWidget);
      expect(find.byKey(const Key('restore-u1')), findsNothing);
      expect(find.text('Lift suspension'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unsuspend-u1')));
      await tester.pumpAndSettle();
      expect(api.params['admin_reports_decide']!['p_action'], 'unsuspend_user');
      expect(api.params['admin_reports_decide']!['p_type'], 'profile');
      expect(api.params['admin_reports_decide']!['p_target'], 'u1');
    });

    testWidgets('Hidden list: hidden content still says Restore', (
      tester,
    ) async {
      final api = await pump(tester, []);
      api.results['admin_reports_list'] = [
        row(type: 'job', id: 'j1', title: 'Staff', hidden: true),
      ];
      await tester.tap(find.text('Hidden'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('restore-j1')), findsOneWidget);
      expect(find.textContaining('Suspended'), findsNothing);
    });

    test('invalid_state also explains that an admin cannot be suspended', () {
      final msg = adminErrorMessage(
        const AdminException(AdminErrorCode.invalidState, 'x'),
      );
      expect(msg, contains('cannot suspend an admin'));
      expect(msg, contains('reload'));
    });
  });
}
