import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';
import 'package:undip_alumni_connect/data/feedback_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/admin_feedback_screen.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/business_form_screen.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';
import 'package:undip_alumni_connect/screens/job_board_screen.dart';
import 'package:undip_alumni_connect/screens/requests_screen.dart';
import 'package:undip_alumni_connect/util/app_info.dart';
import 'package:undip_alumni_connect/widgets/error_view.dart';
import 'package:undip_alumni_connect/widgets/feedback_sheet.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';
import 'support/fake_contact_api.dart';
import 'support/fake_marketplace_api.dart';

class FakeFeedbackApi implements FeedbackApi {
  final rows = <Map<String, dynamic>>[];
  Object? failWith;

  @override
  Future<void> insert(Map<String, dynamic> row) async {
    if (failWith != null) throw failWith!;
    rows.add(row);
  }
}

const info = AppInfo(version: '0.9.0', buildNumber: '7');
const messyError =
    'PostgrestException(message: bad row for budi.santoso@example.com phone +62 812-3456-7890 '
    'key sb_publishable_abcdefghij1234567890 url https://x.supabase.co/rest/v1/a?apikey=zzz, code: 42501)\n'
    '#0 foo (package:a/b.dart:1)';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    AppInfo.shared = info;
    FeedbackSession.profileId = null;
  });
  tearDown(() {
    AppInfo.shared = null;
    FeedbackSession.profileId = null;
  });

  group('report building', () {
    test('reads the version from AppInfo (the same place About uses) and cleans the error', () async {
      FeedbackSession.profileId = 'me';
      final r = await FeedbackRepository.build(
        error: messyError,
        screen: 'Job Board',
        message: ' saya klik kirim ',
      );
      expect(r.appVersion, '0.9.0');
      expect(r.buildNumber, '7');
      expect(r.profileId, 'me');
      expect(r.platform, isNotEmpty);
      for (final bad in [
        'budi',
        '@',
        '0812',
        'sb_publishable',
        'supabase',
        'apikey',
      ]) {
        expect(r.errorText, isNot(contains(bad)), reason: bad);
      }
      expect(r.toRow()['message'], 'saya klik kirim');
      expect(r.toRow().keys.toSet(), {
        'profile_id',
        'message',
        'error_text',
        'screen',
        'app_version',
        'build_number',
        'platform',
      });
    });

    test('before verification there is no profile id, blank message is null, long screen is cut', () async {
      final r = await FeedbackRepository.build(
        error: null,
        screen: 'x' * 80,
        message: '  ',
      );
      final row = r.toRow();
      expect(row['profile_id'], isNull);
      expect(row['message'], isNull);
      expect(row['error_text'], isNull);
      expect((row['screen'] as String).length, 60);
    });
  });

  group('sample error screen', () {
    Future<void> pumpError(WidgetTester tester, {VoidCallback? retry}) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: "Couldn't load jobs. Please try again.",
              screen: 'Job Board',
              error: messyError,
              onRetry: retry,
            ),
          ),
        ),
      );
    }

    testWidgets(
      'friendly message, Try again where there is one, and Send feedback',
      (tester) async {
        var retried = 0;
        await pumpError(tester, retry: () => retried++);
        expect(
          find.text("Couldn't load jobs. Please try again."),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Send feedback'), findsOneWidget);
        expect(
          find.textContaining('Postgrest'),
          findsNothing,
        ); // the raw error is never shown
        await tester.tap(find.text('Try again'));
        expect(retried, 1);
      },
    );

    testWidgets('without a retry action only Send feedback shows', (
      tester,
    ) async {
      await pumpError(tester);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Send feedback'), findsOneWidget);
    });

    testWidgets(
      'the sheet says what is sent, has the optional box, sends a CLEANED report, thanks',
      (tester) async {
        await pumpError(tester);
        final api = FakeFeedbackApi();
        // Open the sheet with our fake repository.
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  onPressed: () => showFeedbackSheet(
                    ctx,
                    error: messyError,
                    screen: 'Job Board',
                    repository: FeedbackRepository(api),
                    appInfo: info,
                    profileId: 'me',
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        final what = tester
            .widget<Text>(find.byKey(const Key('feedback-what')))
            .data!;
        expect(what, contains('error summary'));
        expect(what, contains('Job Board'));
        expect(what, contains('app version'));
        expect(what, contains('device type'));
        expect(find.text('What were you doing? (optional)'), findsOneWidget);
        expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 500);

        await tester.enterText(find.byType(TextField), 'Menekan tombol lamar');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        expect(api.rows.single['screen'], 'Job Board');
        expect(api.rows.single['app_version'], '0.9.0');
        expect(api.rows.single['build_number'], '7');
        expect(api.rows.single['profile_id'], 'me');
        expect(api.rows.single['message'], 'Menekan tombol lamar');
        final sent = '${api.rows.single['error_text']}';
        for (final bad in [
          'budi',
          '@',
          '0812',
          'sb_publishable',
          'supabase',
          'apikey',
        ]) {
          expect(sent, isNot(contains(bad)), reason: bad);
        }
        expect(find.text(kFeedbackThanks), findsOneWidget);
      },
    );

    testWidgets(
      'sending fails: says so and offers Copy details, which copies a pasteable text',
      (tester) async {
        phone(tester);
        String? clip;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clip = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final api = FakeFeedbackApi()
          ..failWith = Exception('SocketException: Failed host lookup');
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  onPressed: () => showFeedbackSheet(
                    ctx,
                    error: messyError,
                    screen: 'Job Board',
                    repository: FeedbackRepository(api),
                    appInfo: info,
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'sedang melamar');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        expect(find.text(kFeedbackFailed), findsOneWidget);
        expect(find.textContaining('SocketException'), findsNothing);
        expect(find.byKey(const Key('feedback-copy')), findsOneWidget);
        expect(find.text(kFeedbackThanks), findsNothing);

        await tester.tap(find.byKey(const Key('feedback-copy')));
        await tester.pumpAndSettle();
        expect(clip, isNotNull);
        expect(clip, contains('Screen: Job Board'));
        expect(clip, contains('v0.9.0 (build 7)'));
        expect(clip, contains('What I was doing: sedang melamar'));
        expect(clip, isNot(contains('@')));
        expect(clip, isNot(contains('sb_publishable')));

        // Trying again after the network is back works.
        api.failWith = null;
        await tester.tap(find.text('Try sending again'));
        await tester.pumpAndSettle();
        expect(api.rows.length, 1);
        expect(find.text(kFeedbackThanks), findsOneWidget);
      },
    );
  });

  group('every error screen and failed form offers Send feedback', () {
    testWidgets('Directory load error', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectoryScreen(
              currentUser: ValueNotifier({'id': 'me'}),
              fetchAlumni: () async =>
                  throw Exception('SocketException: Failed host lookup'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('send-feedback')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Job board load error', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: JobBoardScreen(
            currentUser: ValueNotifier({'id': 'me'}),
            fetchJobs: () async => throw Exception('boom'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('send-feedback')), findsOneWidget);
    });

    testWidgets('Requests load error', (tester) async {
      phone(tester);
      final api = FakeContactApi()..throwOnCall = Exception('boom');
      await tester.pumpWidget(
        MaterialApp(
          home: RequestsScreen(
            currentUser: ValueNotifier({'id': 'me'}),
            repository: ContactRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('send-feedback')), findsWidgets);
    });

    testWidgets('failed business form submit', (tester) async {
      phone(tester);
      tester.view.physicalSize = const Size(600, 3000);
      final api = FakeBusinessApi();
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessFormScreen(
            ownerId: 'me',
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name *'),
        'Kopi Ahmad',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Short description *'),
        'Kopi',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Website link'),
        'https://kopi.example.com',
      );
      await tester.tap(find.byKey(const Key('band-micro')));
      await tester.pump();
      api.throwOnCall = Exception('SocketException: Failed host lookup');
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('business-form-error')), findsOneWidget);
      expect(find.byKey(const Key('send-feedback')), findsOneWidget);
      // A form MISTAKE (no server error) does not offer feedback.
    });

    testWidgets('error snackbar has a Send feedback action', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showErrorSnackBar(
                  ctx,
                  message: 'It failed',
                  screen: 'Test',
                  error: 'boom',
                ),
                child: const Text('GO'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();
      expect(find.text('It failed'), findsOneWidget);
      expect(find.text('Send feedback'), findsOneWidget);
    });

    test(
      'no screen shows friendlyLoadError without the shared error widget',
      () {
        final offenders = <String>[];
        for (final f in Directory('lib').listSync(recursive: true)) {
          if (f is! File || !f.path.endsWith('.dart')) continue;
          if (f.path.endsWith('friendly_error.dart')) continue;
          final text = f.readAsStringSync();
          if (text.contains('friendlyLoadError(') &&
              !text.contains('ErrorView(')) {
            offenders.add(f.path);
          }
        }
        expect(offenders, isEmpty, reason: offenders.join('\n'));
      },
    );
  });

  group('Admin feedback', () {
    Map<String, dynamic> row(
      String id,
      String status, {
      String screen = 'Job Board',
      String? name = 'Siti',
      String when = '2026-10-02T08:00:00Z',
    }) => {
      'id': id,
      'profile_name': name,
      'message': 'sedang melamar',
      'error_text': 'Could not load jobs',
      'screen': screen,
      'app_version': '0.9.0',
      'build_number': '7',
      'platform': 'android',
      'status': status,
      'created_at': when,
    };

    Future<FakeAdminApi> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows,
    ) async {
      phone(tester);
      final api = FakeAdminApi()..results['admin_feedback_list'] = rows;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminFeedbackScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('lists items with the count of new ones', (tester) async {
      final api = await pump(tester, [
        row('a', 'new'),
        row('b', 'seen'),
        row('c', 'new', name: null),
      ]);
      expect(api.params['admin_feedback_list'], {'p_admin': 'me'});
      expect(
        tester.widget<Text>(find.byKey(const Key('feedback-count'))).data,
        '2 new of 3',
      );
      expect(find.textContaining('Not verified'), findsOneWidget);
      expect(
        find.textContaining('Error: Could not load jobs'),
        findsNWidgets(3),
      );
      expect(find.textContaining('v0.9.0 (build 7)'), findsNWidgets(3));
    });

    testWidgets('mark as seen and done', (tester) async {
      final api = await pump(tester, [row('a', 'new')]);
      await tester.tap(find.byKey(const Key('seen-a')));
      await tester.pumpAndSettle();
      expect(api.params['admin_feedback_set_status'], {
        'p_admin': 'me',
        'p_id': 'a',
        'p_status': 'seen',
      });
      await tester.tap(find.byKey(const Key('done-a')));
      await tester.pumpAndSettle();
      expect(api.params['admin_feedback_set_status']!['p_status'], 'done');
    });

    testWidgets('empty state', (tester) async {
      await pump(tester, []);
      expect(find.text('No feedback yet.'), findsOneWidget);
    });

    testWidgets(
      'Admin screen: Feedback section with a badge for new items, no notification',
      (tester) async {
        phone(tester);
        final api = FakeAdminApi()..results['admin_feedback_new_count'] = 5;
        await tester.pumpWidget(
          MaterialApp(
            home: AdminScreen(
              adminId: 'me',
              adminRepository: AdminRepository(api),
              marketplaceRepository: MarketplaceRepository(FakeApi()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final badge = tester.widget<Badge>(
          find.byKey(const Key('feedback-badge')),
        );
        expect(badge.isLabelVisible, isTrue);
        expect((badge.label as Text).data, '5');
        expect(find.byKey(const Key('admin-reports')), findsOneWidget);
        expect(find.byKey(const Key('admin-businesses')), findsOneWidget);
      },
    );
  });
}
