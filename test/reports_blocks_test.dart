import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/block_list.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/data/report_repository.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/models/marketplace_listing.dart';
import 'package:undip_alumni_connect/screens/admin_reports_screen.dart';
import 'package:undip_alumni_connect/screens/blocked_users_screen.dart';
import 'package:undip_alumni_connect/screens/business_directory_screen.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';
import 'package:undip_alumni_connect/screens/home_screen.dart';
import 'package:undip_alumni_connect/screens/job_board_screen.dart';
import 'package:undip_alumni_connect/screens/job_detail_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_detail_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_screen.dart';
import 'package:undip_alumni_connect/screens/my_businesses_screen.dart';
import 'package:undip_alumni_connect/screens/my_listings_screen.dart';
import 'package:undip_alumni_connect/screens/nearby_alumni_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/screens/requests_screen.dart';
import 'package:undip_alumni_connect/widgets/content_actions_menu.dart';
import 'package:undip_alumni_connect/widgets/report_sheet.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';
import 'support/fake_contact_api.dart';
import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';
import 'support/fake_report_api.dart';

final me = ValueNotifier<Map<String, dynamic>>({
  'id': 'me',
  'name': 'Me',
  'city': 'Semarang',
});

void phone(WidgetTester tester, {double w = 420, double h = 1600}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  final defaultBlocks = BlockList.shared;
  tearDown(() => BlockList.shared = defaultBlocks);

  group('ReportRepository', () {
    test('sends the database values, blank note as null', () async {
      final api = FakeReportApi();
      await ReportRepository(api).report(
        reporterId: 'me',
        type: ReportTarget.contactRequest,
        targetId: 'r1',
        reason: ContentReportReason.fakeOrImpersonation,
        note: '  ',
      );
      expect(api.params['content_report_create'], {
        'p_reporter': 'me',
        'p_type': 'contact_request',
        'p_target': 'r1',
        'p_reason': 'fake_or_impersonation',
        'p_note': null,
      });
    });

    test('five reasons, plain labels', () {
      expect(ContentReportReason.values.map((r) => r.value), [
        'spam_or_scam',
        'inappropriate',
        'fake_or_impersonation',
        'wrong_info',
        'other',
      ]);
      expect(ReportTarget.values.map((r) => r.value), [
        'job',
        'product',
        'business',
        'profile',
        'contact_request',
      ]);
    });

    test('database codes become plain messages', () async {
      final cases = {
        'already_reported': ReportErrorCode.alreadyReported,
        'cannot_report_own': ReportErrorCode.cannotReportOwn,
        'not_verified': ReportErrorCode.notVerified,
      };
      for (final e in cases.entries) {
        final api = FakeReportApi()..throwOnCall = pgError(e.key);
        try {
          await ReportRepository(api).report(
            reporterId: 'me',
            type: ReportTarget.job,
            targetId: 'j',
            reason: ContentReportReason.other,
          );
          fail('should throw');
        } on ReportException catch (ex) {
          expect(ex.code, e.value);
          expect(reportErrorMessage(ex), isNot(contains('_')));
        }
      }
    });
  });

  group('report sheet', () {
    Future<FakeReportApi> open(WidgetTester tester) async {
      phone(tester);
      final api = FakeReportApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showContentReportSheet(
                  ctx,
                  repository: ReportRepository(api),
                  reporterId: 'me',
                  type: ReportTarget.business,
                  targetId: 'b1',
                  what: 'this business',
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('reason picker, optional note with a 300 limit', (
      tester,
    ) async {
      await open(tester);
      for (final r in ContentReportReason.values) {
        expect(find.text(r.label), findsOneWidget);
      }
      expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 300);
    });

    testWidgets('needs a reason first, then sends and says thank you', (
      tester,
    ) async {
      final api = await open(tester);
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a reason.'), findsOneWidget);
      expect(api.calls, isEmpty);

      await tester.tap(find.byKey(const Key('reason-spam_or_scam')));
      await tester.enterText(find.byType(TextField), 'Menipu');
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(api.params['content_report_create'], {
        'p_reporter': 'me',
        'p_type': 'business',
        'p_target': 'b1',
        'p_reason': 'spam_or_scam',
        'p_note': 'Menipu',
      });
      expect(find.text(kReportThanks), findsOneWidget);
    });

    testWidgets('already reported: plain message, sheet stays', (tester) async {
      final api = await open(tester);
      api.throwOnCall = pgError('already_reported');
      await tester.tap(find.byKey(const Key('reason-other')));
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-error')), findsOneWidget);
      expect(find.text('Send report'), findsOneWidget);
    });
  });

  group('content actions menu', () {
    Future<(FakeReportApi, FakeBlockApi, BlockList)> pump(
      WidgetTester tester, {
      String ownerId = 'u2',
      ReportTarget? type = ReportTarget.job,
      VoidCallback? onBlocked,
    }) async {
      phone(tester);
      final rApi = FakeReportApi();
      final bApi = FakeBlockApi();
      final list = BlockList(BlockRepository(bApi));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ContentActionsMenu(
                  currentUserId: 'me',
                  ownerId: ownerId,
                  ownerName: 'Siti',
                  reportType: type,
                  targetId: type == null ? null : 't1',
                  reportRepository: ReportRepository(rApi),
                  blockList: list,
                  onBlocked: onBlocked,
                ),
              ],
            ),
          ),
        ),
      );
      return (rApi, bApi, list);
    }

    testWidgets('not shown on my own content', (tester) async {
      await pump(tester, ownerId: 'me');
      expect(find.byKey(const Key('content-menu')), findsNothing);
    });

    testWidgets('Report and Block for someone else', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('content-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Block this person'), findsOneWidget);
    });

    testWidgets('no Report entry when the thing keeps its own report flow', (
      tester,
    ) async {
      await pump(tester, type: null);
      await tester.tap(find.byKey(const Key('content-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsNothing);
      expect(find.text('Block this person'), findsOneWidget);
    });

    testWidgets('block asks first; cancel changes nothing', (tester) async {
      final (_, bApi, list) = await pump(tester);
      await tester.tap(find.byKey(const Key('content-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block this person'));
      await tester.pumpAndSettle();
      expect(find.text('Block Siti?'), findsOneWidget);
      expect(find.textContaining('They are not told'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(bApi.calls, isEmpty);
      expect(list.isBlocked('u2'), isFalse);
    });

    testWidgets('confirming blocks and updates the shared list', (
      tester,
    ) async {
      var blocked = 0;
      final (_, bApi, list) = await pump(tester, onBlocked: () => blocked++);
      await tester.tap(find.byKey(const Key('content-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block this person'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();
      expect(bApi.params['user_block'], {'p_blocker': 'me', 'p_blocked': 'u2'});
      expect(list.isBlocked('u2'), isTrue);
      expect(blocked, 1);
    });
  });

  group('actions are on the right screens', () {
    Map<String, dynamic> job({String by = 'u2'}) => {
      'id': 'j1',
      'title': 'Staff',
      'company': 'PT',
      'description': 'd',
      'posted_by': by,
      'poster': {'name': 'Siti'},
    };

    testWidgets('job detail: menu on others jobs, none on mine', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            job: job(),
            currentUser: me,
            loadApplicantCount: () async => 0,
            loadHasApplied: () async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-menu')), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: JobDetailScreen(
            job: job(by: 'me'),
            currentUser: me,
            loadApplicantCount: () async => 0,
            loadHasApplied: () async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-menu')), findsNothing);
    });

    testWidgets('business detail: menu on others, none on mine', (
      tester,
    ) async {
      phone(tester);
      Widget screen(String owner) => MaterialApp(
        key: UniqueKey(),
        home: BusinessDetailScreen(
          business: Business.fromMap(
            businessMap(ownerId: owner, status: 'approved', ownerName: 'Siti'),
          ),
          currentUser: me,
        ),
      );
      await tester.pumpWidget(screen('u2'));
      expect(find.byKey(const Key('content-menu')), findsOneWidget);
      await tester.pumpWidget(screen('me'));
      expect(find.byKey(const Key('content-menu')), findsNothing);
    });

    testWidgets('profile: menu on someone else, none on mine', (tester) async {
      phone(tester);
      Widget screen(String id, bool edit) => MaterialApp(
        key: UniqueKey(),
        home: ProfileDetailScreen(
          profile: {'id': id, 'name': 'Siti'},
          currentUser: me,
          showEditButton: edit,
          chat: false,
          adminCheck: (_) async => false,
        ),
      );
      await tester.pumpWidget(screen('u2', false));
      expect(find.byKey(const Key('content-menu')), findsOneWidget);
      await tester.pumpWidget(screen('me', true));
      expect(find.byKey(const Key('content-menu')), findsNothing);
      expect(find.byKey(const Key('profile-blocked')), findsOneWidget);
    });

    testWidgets('each received contact request has Report and Block', (
      tester,
    ) async {
      phone(tester);
      final api = FakeContactApi()
        ..results['contact_requests_incoming'] = [incomingMap()];
      await tester.pumpWidget(
        MaterialApp(
          home: RequestsScreen(
            currentUser: me,
            repository: ContactRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Block this person'), findsOneWidget);
    });

    testWidgets(
      'product detail: keeps its own Report button, adds Block only',
      (tester) async {
        phone(tester, h: 2400);
        await tester.pumpWidget(
          MaterialApp(
            home: MarketplaceDetailScreen(
              listing: MarketplaceListing.fromMap(
                listingMap(seller: sellerMap),
              ),
              repository: MarketplaceRepository(FakeApi()),
              currentUser: me,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Report listing'), findsOneWidget);
        await tester.tap(find.byKey(const Key('content-menu')));
        await tester.pumpAndSettle();
        expect(find.text('Block this person'), findsOneWidget);
        expect(find.byKey(const Key('menu-report')), findsNothing);
      },
    );
  });

  group('every list leaves out people I blocked', () {
    setUp(() => BlockList.shared = BlockList.preloaded({'bad'}));

    testWidgets('Directory', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectoryScreen(
              currentUser: me,
              fetchAlumni: () async => [
                {
                  'id': 'ok',
                  'name': 'Siti Baik',
                  'major': 'Manajemen',
                  'graduation_year': 2020,
                },
                {
                  'id': 'bad',
                  'name': 'Budi Diblokir',
                  'major': 'Manajemen',
                  'graduation_year': 2020,
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siti Baik'), findsOneWidget);
      expect(find.text('Budi Diblokir'), findsNothing);
    });

    testWidgets('Nearby', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyAlumniScreen(
              currentUser: me,
              fetchAlumni: () async => [
                {'id': 'me', 'name': 'Me', 'city': 'Semarang'},
                {
                  'id': 'ok',
                  'name': 'Siti Baik',
                  'city': 'Jakarta',
                  'current_role': 'x',
                },
                {
                  'id': 'bad',
                  'name': 'Budi Diblokir',
                  'city': 'Jakarta',
                  'current_role': 'x',
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siti Baik'), findsOneWidget);
      expect(find.text('Budi Diblokir'), findsNothing);
    });

    testWidgets('Job board', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: JobBoardScreen(
            currentUser: me,
            fetchUnreadCount: () async => 0,
            fetchJobs: () async => [
              {
                'id': 'j1',
                'title': 'Staff Baik',
                'company': 'PT A',
                'description': 'd',
                'posted_by': 'ok',
                'poster': {'name': 'A'},
              },
              {
                'id': 'j2',
                'title': 'Staff Diblokir',
                'company': 'PT B',
                'description': 'd',
                'posted_by': 'bad',
                'poster': {'name': 'B'},
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Staff Baik'), findsOneWidget);
      expect(find.text('Staff Diblokir'), findsNothing);
    });

    testWidgets('Home latest jobs and latest products', (tester) async {
      phone(tester, h: 2200);
      final market = FakeApi()
        ..approved = [
          {...listingMap(id: 'l1', title: 'Produk Baik'), 'seller_id': 'ok'},
          {
            ...listingMap(id: 'l2', title: 'Produk Diblokir'),
            'seller_id': 'bad',
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentUser: me,
            onOpenDirectory: () {},
            pages: fakePages(),
            api: FakeHomeApi(
              jobs: [
                {...jobMap(1), 'title': 'Job Baik', 'posted_by': 'ok'},
                {...jobMap(2), 'title': 'Job Diblokir', 'posted_by': 'bad'},
              ],
            ),
            marketplaceRepository: MarketplaceRepository(market),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.text('Job Baik'), findsOneWidget);
      expect(find.text('Job Diblokir'), findsNothing);
      expect(find.text('Produk Baik'), findsOneWidget);
      expect(find.text('Produk Diblokir'), findsNothing);
    });

    testWidgets('Marketplace', (tester) async {
      phone(tester);
      final market = FakeApi()
        ..approved = [
          {
            ...listingMap(id: 'l1', title: 'Produk Baik', seller: sellerMap),
            'seller_id': 'ok',
          },
          {
            ...listingMap(
              id: 'l2',
              title: 'Produk Diblokir',
              seller: sellerMap,
            ),
            'seller_id': 'bad',
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceScreen(
            currentUser: me,
            repository: MarketplaceRepository(market),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Produk Baik'), findsOneWidget);
      expect(find.text('Produk Diblokir'), findsNothing);
    });

    testWidgets('Business directory', (tester) async {
      phone(tester);
      final api = FakeBusinessApi()
        ..results['business_directory'] = [
          {
            ...businessMap(
              id: '1',
              name: 'Toko Baik',
              ownerId: 'ok',
              status: 'approved',
            ),
            'owner_name': 'A',
          },
          {
            ...businessMap(
              id: '2',
              name: 'Toko Diblokir',
              ownerId: 'bad',
              status: 'approved',
              social: 'https://x.example/2',
            ),
            'owner_name': 'B',
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessDirectoryScreen(
            currentUser: me,
            repository: BusinessRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Toko Baik'), findsOneWidget);
      expect(find.text('Toko Diblokir'), findsNothing);
    });

    testWidgets('admin screens still show everything', (tester) async {
      phone(tester);
      final market = FakeApi()
        ..approved = [
          {
            ...listingMap(id: 'l2', title: 'Produk Diblokir'),
            'seller_id': 'bad',
          },
        ];
      final all = await MarketplaceRepository(market)
          .fetchApproved(applyBlocks: false);
      expect(all.single.title, 'Produk Diblokir');
    });

    test('filter keeps everything when nothing is blocked, and ignores null owners', () {
      final empty = BlockList.preloaded({});
      expect(empty.filter([1, 2], (i) => '$i'), [1, 2]);
      final one = BlockList.preloaded({'a'});
      expect(one.filter(['a', 'b', 'c'], (s) => s == 'c' ? null : s), [
        'b',
        'c',
      ]);
    });
  });

  group('Blocked users screen', () {
    testWidgets('lists people, Unblock works, empty state', (tester) async {
      phone(tester);
      final api = FakeBlockApi()
        ..results['user_blocks_list'] = [
          {
            'blocked_id': 'u2',
            'name': 'Siti Azizah',
            'created_at': '2026-10-01T00:00:00Z',
          },
        ];
      final list = BlockList(BlockRepository(api))..blocked.value = {'u2'};
      await tester.pumpWidget(
        MaterialApp(
          home: BlockedUsersScreen(
            currentUserId: 'me',
            repository: BlockRepository(api),
            blockList: list,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siti Azizah'), findsOneWidget);
      api.results['user_blocks_list'] = <dynamic>[];
      await tester.tap(find.byKey(const Key('unblock-u2')));
      await tester.pumpAndSettle();
      expect(api.params['user_unblock'], {
        'p_blocker': 'me',
        'p_blocked': 'u2',
      });
      expect(list.isBlocked('u2'), isFalse);
      expect(find.text('You have not blocked anyone.'), findsOneWidget);
    });
  });

  group('Admin Reports screen', () {
    Map<String, dynamic> row({
      String type = 'job',
      String id = 't1',
      String title = 'Staff Keuangan (PT Maju)',
      int count = 2,
      List<String> reasons = const ['spam_or_scam', 'wrong_info'],
      bool hidden = false,
    }) => {
      'target_type': type,
      'target_id': id,
      'title': title,
      'owner_id': 'o',
      'owner_name': 'Ahmad',
      'report_count': count,
      'reasons': reasons,
      'notes': ['lowongan palsu'],
      'last_reported': '2026-10-02T00:00:00Z',
      'is_hidden': hidden,
      'hidden_reason': hidden ? 'Palsu' : null,
    };

    Future<FakeAdminApi> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows, {
      List<Map<String, dynamic>>? hiddenRows,
    }) async {
      phone(tester);
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

    testWidgets('shows preview, report count and reasons', (tester) async {
      final api = await pump(tester, [
        row(),
        row(
          type: 'product',
          id: 'p1',
          title: 'Kopi',
          count: 1,
          reasons: ['inappropriate'],
        ),
      ]);
      expect(api.params['admin_reports_list'], {
        'p_admin': 'me',
        'p_view': 'open',
      });
      expect(find.text('Job: Staff Keuangan (PT Maju)'), findsOneWidget);
      expect(
        find.textContaining('2 reports: Spam or scam, Wrong information'),
        findsOneWidget,
      );
      expect(find.text('Product: Kopi'), findsOneWidget);
      expect(find.textContaining('1 report: Inappropriate'), findsOneWidget);
    });

    testWidgets('dismiss', (tester) async {
      final api = await pump(tester, [row()]);
      await tester.tap(find.byKey(const Key('dismiss-t1')));
      await tester.pumpAndSettle();
      expect(api.params['admin_reports_decide'], {
        'p_admin': 'me',
        'p_type': 'job',
        'p_target': 't1',
        'p_action': 'dismiss',
        'p_reason': null,
      });
    });

    testWidgets('hide needs a reason, nothing is automatic', (tester) async {
      final api = await pump(tester, [row()]);
      expect(api.calls, ['admin_reports_list']);
      await tester.tap(find.byKey(const Key('hide-t1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Hide'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A reason is required'), findsOneWidget);
      expect(api.calls.contains('admin_reports_decide'), isFalse);
      await tester.enterText(find.byType(TextField), 'Lowongan palsu');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Hide'),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.params['admin_reports_decide']!['p_action'], 'hide');
      expect(api.params['admin_reports_decide']!['p_reason'], 'Lowongan palsu');
    });

    testWidgets(
      'profiles and requests cannot be hidden, only dismissed or marked handled',
      (tester) async {
        await pump(tester, [
          row(type: 'profile', id: 'pr1', title: 'Budi'),
          row(type: 'contact_request', id: 'cr1', title: 'Halo'),
        ]);
        expect(find.byKey(const Key('hide-pr1')), findsNothing);
        expect(find.byKey(const Key('actioned-pr1')), findsOneWidget);
        expect(find.byKey(const Key('dismiss-cr1')), findsOneWidget);
      },
    );

    testWidgets('hidden view: restore', (tester) async {
      final api = await pump(tester, []);
      api.results['admin_reports_list'] = [
        row(hidden: true, count: 0, reasons: []),
      ];
      await tester.tap(find.text('Hidden'));
      await tester.pumpAndSettle();
      expect(api.params['admin_reports_list']!['p_view'], 'hidden');
      expect(find.textContaining('Hidden: Palsu'), findsOneWidget);
      await tester.tap(find.byKey(const Key('restore-t1')));
      await tester.pumpAndSettle();
      expect(api.params['admin_reports_decide']!['p_action'], 'restore');
    });
  });

  group('owners are told when something is hidden', () {
    testWidgets('business card', (tester) async {
      phone(tester);
      final api = FakeBusinessApi()
        ..results['business_my'] = [
          {
            ...businessMap(status: 'approved', approvedBand: 'micro'),
            'hidden_at': '2026-10-02T00:00:00Z',
            'hidden_reason': 'Penipuan',
          },
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
      expect(
        find.textContaining('Hidden by an admin: Penipuan'),
        findsOneWidget,
      );
    });

    testWidgets('product card', (tester) async {
      phone(tester);
      final api = FakeApi()
        ..rpcResults['marketplace_my_listings'] = [
          {
            ...listingMap(),
            'hidden_at': '2026-10-02T00:00:00Z',
            'hidden_reason': 'Foto curian',
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: MyListingsScreen(
            sellerId: 's1',
            repository: MarketplaceRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Hidden by an admin: Foto curian'),
        findsOneWidget,
      );
    });
  });
}
