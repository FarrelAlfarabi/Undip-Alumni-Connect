import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/home_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/screens/requests_screen.dart';

import 'support/fake_contact_api.dart';
import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

final me = {'id': 'me', 'name': 'Ahmad Ramadhan'};
final other = {
  'id': 'u2',
  'name': 'Siti Azizah',
  'faculty': 'FEB',
  'major': 'Manajemen',
  'graduation_year': 2020,
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('repository', () {
    test(
      'send trims, sends a blank message as null, uses the requester id',
      () async {
        final api = FakeContactApi();
        await ContactRepository(api)
            .send(requesterId: 'me', targetId: 'u2', message: '   ');
        expect(api.params['contact_request_send'], {
          'p_requester': 'me',
          'p_target': 'u2',
          'p_message': null,
        });
        await ContactRepository(api)
            .send(requesterId: 'me', targetId: 'u2', message: ' hai ');
        expect(api.params['contact_request_send']!['p_message'], 'hai');
      },
    );

    test('database codes become plain messages', () async {
      final cases = {
        'request_already_open': ContactErrorCode.requestAlreadyOpen,
        'cooldown_active': ContactErrorCode.cooldownActive,
        'daily_limit_reached': ContactErrorCode.dailyLimitReached,
        'too_many_open': ContactErrorCode.tooManyOpen,
        'already_shared': ContactErrorCode.alreadyShared,
        'not_accepted': ContactErrorCode.notAccepted,
        'shared_required': ContactErrorCode.sharedRequired,
      };
      for (final e in cases.entries) {
        final api = FakeContactApi()..throwOnCall = pgFail(e.key);
        try {
          await ContactRepository(api).send(requesterId: 'me', targetId: 'u2');
          fail('should throw');
        } on ContactException catch (ex) {
          expect(ex.code, e.value);
          expect(contactErrorMessage(ex), isNot(contains('_')));
        }
      }
    });

    test('limit messages say the number and what to do next', () {
      String msg(ContactErrorCode c) =>
          contactErrorMessage(ContactException(c, ''));
      expect(msg(ContactErrorCode.tooManyOpen), contains('$kOpenRequestMax'));
      expect(
        msg(ContactErrorCode.dailyLimitReached),
        contains('$kDailyRequestMax'),
      );
      expect(msg(ContactErrorCode.alreadyShared), contains('Requests'));
    });

    test('lists never read a shared contact column', () async {
      final api = FakeContactApi()
        ..results['contact_requests_outgoing'] = [
          outgoingMap(status: 'accepted'),
        ];
      final list = await ContactRepository(api).outgoing('me');
      expect(list.single.status.name, 'accepted');
      expect(api.calls, ['contact_requests_outgoing']);
    });
  });

  group('profile button', () {
    Future<FakeContactApi> pump(
      WidgetTester tester,
      Map<String, dynamic> profile, {
      bool showEdit = false,
      FakeContactApi? withApi,
    }) async {
      phone(tester);
      final api = withApi ?? FakeContactApi();
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileDetailScreen(
            profile: profile,
            currentUser: ValueNotifier(me),
            showEditButton: showEdit,
            chat: false,
            contactRepository: ContactRepository(api),
          ),
        ),
      );
      return api;
    }

    testWidgets('shown on another alumnus profile', (tester) async {
      await pump(tester, other);
      expect(find.text('Minta kontak'), findsOneWidget);
    });

    testWidgets('an open request to this person shows as sent, not a button', (
      tester,
    ) async {
      final api = FakeContactApi()
        ..results['contact_requests_outgoing'] = [
          outgoingMap(targetId: 'u2', name: 'Siti Azizah'),
        ];
      await pump(tester, other, withApi: api);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('request-sent')), findsOneWidget);
      expect(find.byKey(const Key('request-contact')), findsNothing);
      expect(find.textContaining('menunggu jawaban'), findsOneWidget);
    });

    testWidgets('an answered request does not block a new one', (tester) async {
      final api = FakeContactApi()
        ..results['contact_requests_outgoing'] = [
          outgoingMap(targetId: 'u2', status: 'rejected'),
        ];
      await pump(tester, other, withApi: api);
      expect(find.byKey(const Key('request-contact')), findsOneWidget);
    });

    testWidgets('after sending, the button turns into the sent state', (
      tester,
    ) async {
      await pump(tester, other);
      await tester.tap(find.byKey(const Key('request-contact')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim permintaan'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('request-sent')), findsOneWidget);
      expect(find.byKey(const Key('request-contact')), findsNothing);
    });

    testWidgets('not shown on my own profile (either way of opening it)', (
      tester,
    ) async {
      await pump(tester, me, showEdit: true);
      expect(find.text('Minta kontak'), findsNothing);
      await pump(tester, me);
      expect(find.text('Minta kontak'), findsNothing);
    });

    testWidgets('sheet: optional message, 200 limit, sends and confirms', (
      tester,
    ) async {
      final api = await pump(tester, other);
      await tester.tap(find.byKey(const Key('request-contact')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 200);
      await tester.enterText(
        find.byType(TextField),
        'Saya ingin bertanya soal karier',
      );
      await tester.tap(find.text('Kirim permintaan'));
      await tester.pumpAndSettle();
      expect(api.params['contact_request_send'], {
        'p_requester': 'me',
        'p_target': 'u2',
        'p_message': 'Saya ingin bertanya soal karier',
      });
      expect(find.text('Permintaan terkirim ke Siti Azizah.'), findsOneWidget);
    });

    testWidgets('a blocked send shows a plain message and keeps the sheet', (
      tester,
    ) async {
      final api = await pump(tester, other);
      api.throwOnCall = pgFail('request_already_open');
      await tester.tap(find.byKey(const Key('request-contact')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim permintaan'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('already have an open request'),
        findsOneWidget,
      );
      expect(find.text('Kirim permintaan'), findsOneWidget);
    });
  });

  group('Requests screen', () {
    Future<FakeContactApi> pump(
      WidgetTester tester, {
      List<Map<String, dynamic>> incoming = const [],
      List<Map<String, dynamic>> outgoing = const [],
      int tab = 0,
    }) async {
      phone(tester);
      final api = FakeContactApi()
        ..results['contact_requests_incoming'] = incoming
        ..results['contact_requests_outgoing'] = outgoing;
      await tester.pumpWidget(
        MaterialApp(
          home: RequestsScreen(
            currentUser: ValueNotifier(me),
            repository: ContactRepository(api),
            initialTab: tab,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('empty states', (tester) async {
      await pump(tester);
      expect(find.textContaining('Belum ada permintaan'), findsOneWidget);
      await tester.tap(find.text('Terkirim'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('belum meminta kontak siapa pun'),
        findsOneWidget,
      );
    });

    testWidgets('accept needs typed text and sends it', (tester) async {
      final api = await pump(tester, incoming: [incomingMap()]);
      expect(find.text('Halo, boleh kenalan?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('accept-r1')));
      await tester.pumpAndSettle();
      // Nothing typed: refused, nothing sent.
      await tester.tap(find.text('Terima dan bagikan'));
      await tester.pumpAndSettle();
      expect(find.text('Isi kontak yang ingin kamu bagikan.'), findsOneWidget);
      expect(api.calls.contains('contact_request_respond'), isFalse);

      await tester.enterText(
        find.byKey(const Key('share-field')),
        'WA 0812-0000',
      );
      await tester.tap(find.text('Terima dan bagikan'));
      await tester.pumpAndSettle();
      expect(api.params['contact_request_respond'], {
        'p_target': 'me',
        'p_request': 'r1',
        'p_accept': true,
        'p_shared': 'WA 0812-0000',
      });
    });

    testWidgets('decline sends accept false and no text', (tester) async {
      final api = await pump(tester, incoming: [incomingMap()]);
      await tester.tap(find.byKey(const Key('reject-r1')));
      await tester.pumpAndSettle();
      expect(api.params['contact_request_respond']!['p_accept'], false);
      expect(api.params['contact_request_respond']!['p_shared'], isNull);
    });

    testWidgets('answered requests show no buttons', (tester) async {
      await pump(
        tester,
        incoming: [
          incomingMap(status: 'accepted'),
          incomingMap(id: 'r2', status: 'rejected'),
        ],
      );
      expect(find.text('Terima'), findsNothing);
      expect(find.text('Kamu sudah menerima permintaan ini.'), findsOneWidget);
      expect(find.text('Kamu sudah menolak permintaan ini.'), findsOneWidget);
    });

    testWidgets(
      'sent: pending, rejected shows only "Not accepted", accepted reveals contact on tap',
      (tester) async {
        final api = await pump(
          tester,
          tab: 1,
          outgoing: [
            outgoingMap(id: 'a', status: 'pending'),
            outgoingMap(id: 'b', status: 'rejected', name: 'Bunga'),
            outgoingMap(id: 'c', status: 'accepted', name: 'Clara'),
          ],
        );
        api.results['contact_request_shared_contact'] = 'clara@example.com';
        expect(find.byKey(const Key('status-a')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('status-a'))).data,
          'Menunggu jawaban',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('status-b'))).data,
          'Belum diterima',
        );
        expect(find.byKey(const Key('show-b')), findsNothing);
        expect(find.byKey(const Key('show-a')), findsNothing);
        // The shared contact is not on screen, and was not fetched, until tapped.
        expect(find.text('clara@example.com'), findsNothing);
        expect(api.calls.contains('contact_request_shared_contact'), isFalse);

        await tester.tap(find.byKey(const Key('show-c')));
        await tester.pumpAndSettle();
        expect(api.params['contact_request_shared_contact'], {
          'p_requester': 'me',
          'p_request': 'c',
        });
        expect(find.text('clara@example.com'), findsOneWidget);
      },
    );

    testWidgets('a failed load shows a friendly message and Try again', (
      tester,
    ) async {
      phone(tester);
      final api = FakeContactApi()
        ..throwOnCall = Exception('SocketException: Failed host lookup');
      await tester.pumpWidget(
        MaterialApp(
          home: RequestsScreen(
            currentUser: ValueNotifier(me),
            repository: ContactRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your connection'), findsWidgets);
      expect(find.textContaining('SocketException'), findsNothing);
    });
  });

  group('Home badge', () {
    Future<void> pumpHome(WidgetTester tester, int pending) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentUser: ValueNotifier(me),
            onOpenDirectory: () {},
            pages: fakePages(),
            api: FakeHomeApi(pendingRequests: pending),
            marketplaceRepository: MarketplaceRepository(FakeApi()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows the number of waiting requests', (tester) async {
      await pumpHome(tester, 3);
      final badge = tester.widget<Badge>(
        find.byKey(const Key('requests-badge')),
      );
      expect(badge.isLabelVisible, isTrue);
      expect((badge.label as Text).data, '3');
    });

    testWidgets('no badge when nothing waits, and the icon opens Requests', (
      tester,
    ) async {
      await pumpHome(tester, 0);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('requests-badge')))
            .isLabelVisible,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('home-requests')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE Requests'), findsOneWidget);
    });
  });
}
