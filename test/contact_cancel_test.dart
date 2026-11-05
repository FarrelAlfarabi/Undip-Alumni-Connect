import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';
import 'package:undip_alumni_connect/models/contact_request.dart';
import 'package:undip_alumni_connect/screens/requests_screen.dart';

import 'support/fake_contact_api.dart';

void main() {
  group('error messages tell the two lock cases apart', () {
    String msg(ContactErrorCode c) =>
        contactErrorMessage(ContactException(c, c.name));

    test('cooldown says they declined in the last 30 days', () {
      expect(msg(ContactErrorCode.cooldownActive), contains('30 hari'));
      expect(msg(ContactErrorCode.cooldownActive), contains('menolak'));
    });

    test('blocked stays vague on purpose and differs from cooldown', () {
      final blocked = msg(ContactErrorCode.blocked);
      expect(blocked, isNot(msg(ContactErrorCode.cooldownActive)));
      expect(blocked, isNot(contains('blokir')));
      expect(blocked, isNot(contains('menolak')));
    });
  });

  test('cancelled status parses', () {
    expect(
      ContactRequestStatus.parse('cancelled'),
      ContactRequestStatus.cancelled,
    );
  });

  test('cancel sends requester and request', () async {
    final api = FakeContactApi();
    await ContactRepository(api).cancel(requesterId: 'me', requestId: 'r1');
    expect(api.params['contact_request_cancel'], {
      'p_requester': 'me',
      'p_request': 'r1',
    });
  });

  testWidgets('a pending sent request can be cancelled after confirming', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeContactApi()
      ..results['contact_requests_incoming'] = []
      ..results['contact_requests_outgoing'] = [
        {
          'id': 'r1',
          'target_id': 't1',
          'target_name': 'Siti',
          'status': 'pending',
          'created_at': '2026-11-01T08:00:00+00:00',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: RequestsScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          repository: ContactRepository(api),
          initialTab: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-r1')));
    await tester.pumpAndSettle();
    expect(api.calls.contains('contact_request_cancel'), isFalse);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(api.params['contact_request_cancel'], {
      'p_requester': 'me',
      'p_request': 'r1',
    });
  });
}
