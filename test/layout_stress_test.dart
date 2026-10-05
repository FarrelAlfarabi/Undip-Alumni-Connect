import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/account_repository.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/block_list.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';
import 'package:undip_alumni_connect/data/feedback_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/data/notification_repository.dart';
import 'package:undip_alumni_connect/data/report_repository.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/policy/consent_screen.dart';
import 'package:undip_alumni_connect/policy/policy_screen.dart';
import 'package:undip_alumni_connect/screens/about_screen.dart';
import 'package:undip_alumni_connect/screens/admin_feedback_screen.dart';
import 'package:undip_alumni_connect/screens/admin_reports_screen.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/blocked_users_screen.dart';
import 'package:undip_alumni_connect/screens/business_directory_screen.dart';
import 'package:undip_alumni_connect/screens/business_form_screen.dart';
import 'package:undip_alumni_connect/screens/delete_account_screen.dart';
import 'package:undip_alumni_connect/screens/home_screen.dart';
import 'package:undip_alumni_connect/screens/home_shell.dart';
import 'package:undip_alumni_connect/screens/market_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_form_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_report_sheet.dart';
import 'package:undip_alumni_connect/screens/marketplace_screen.dart';
import 'package:undip_alumni_connect/screens/my_businesses_screen.dart';
import 'package:undip_alumni_connect/screens/nearby_alumni_screen.dart';
import 'package:undip_alumni_connect/screens/notifications_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/screens/request_contact_sheet.dart';
import 'package:undip_alumni_connect/screens/requests_screen.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';
import 'package:undip_alumni_connect/util/app_info.dart';
import 'package:undip_alumni_connect/widgets/error_view.dart';
import 'package:undip_alumni_connect/widgets/feedback_sheet.dart';
import 'package:undip_alumni_connect/widgets/report_sheet.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';
import 'support/fake_contact_api.dart';
import 'support/fake_home.dart';
import 'support/fake_lock.dart';
import 'support/fake_marketplace_api.dart';
import 'support/fake_report_api.dart';

// ---------------------------------------------------------------------------
// Realistic (long) data
// ---------------------------------------------------------------------------

const longName = 'Muhammad Fajar Ramadhan Nugroho Wijayakusuma';
const longBiz =
    'Warung Kopi dan Roti Bakar Nusantara Sejahtera Bersama Alumni Undip';
const longDesc =
    'Menyediakan kopi arabika pilihan dari lereng Gunung Ungaran, roti bakar '
    'dengan berbagai rasa, serta layanan katering untuk acara reuni, '
    'wisuda, dan pertemuan keluarga besar alumni di seluruh Jawa Tengah.';
const longFaculty = 'Fakultas Ilmu Sosial dan Ilmu Politik';
const longMajor = 'Administrasi Publik dan Kebijakan Pembangunan Daerah';
const longCity = 'Kabupaten Tulungagung Jawa Timur';

final me = ValueNotifier<Map<String, dynamic>>({
  'id': 'me',
  'name': longName,
  'email': 'muhammad.fajar.ramadhan.nugroho.wijayakusuma@students.undip.ac.id',
  'nim': '21120112130099',
  'faculty': longFaculty,
  'major': longMajor,
  'graduation_year': 2016,
  'city': longCity,
  'current_role': 'Kepala Divisi Perencanaan dan Pengembangan Strategis',
  'current_employer': 'PT Pembangunan Jaya Sentosa Abadi Nusantara Raya',
  'industry': 'Konstruksi dan Infrastruktur',
  'company': 'PT Pembangunan Jaya Sentosa Abadi Nusantara Raya',
  'subscription_status': 'free',
});

Map<String, dynamic> bizRow(int i, {String status = 'approved'}) => {
  ...businessMap(
    id: 'b$i',
    ownerId: i == 0 ? 'me' : 'u$i',
    name: '$longBiz $i',
    description: longDesc,
    category: 'Food & Drink',
    status: status,
    social: 'https://instagram.com/warung_kopi_nusantara_sejahtera_bersama',
    website: 'https://www.warungkopinusantarasejahterabersama.co.id/menu',
    requestedBand: 'small',
    approvedBand: status == 'approved' ? 'small' : null,
    reason: status == 'rejected'
        ? 'Tautan media sosial tidak dapat dibuka, mohon perbaiki lalu kirim '
              'ulang untuk ditinjau kembali oleh tim admin.'
        : null,
    ownerName: longName,
  ),
};

List<Map<String, dynamic>> bizRows([int n = 9]) => [
  for (var i = 0; i < n; i++)
    bizRow(
      i,
      status: const ['approved', 'pending', 'rejected', 'suspended'][i % 4],
    ),
];

List<Map<String, dynamic>> approvedBizRows([int n = 9]) => [
  for (var i = 0; i < n; i++) bizRow(i),
];

final longSeller = {
  ...sellerMap,
  'name': longName,
  'faculty': longFaculty,
  'major': longMajor,
  'city': longCity,
};

List<Map<String, dynamic>> listingRows([int n = 9]) => [
  for (var i = 0; i < n; i++)
    {
      ...listingMap(
        id: 'l$i',
        title: 'Kopi Arabika Gunung Ungaran Premium Roasted Medium $i',
        priceIdr: 1250000 + i,
        city: longCity,
        seller: longSeller,
        shopUrl: 'https://shop.example.com/kopi-arabika-gunung-ungaran',
      ),
      'description': longDesc,
    },
];

List<Map<String, dynamic>> incomingRows([int n = 9]) => [
  for (var i = 0; i < n; i++)
    incomingMap(
      id: 'r$i',
      requesterId: 'u$i',
      name: longName,
      message:
          'Halo Kak, saya satu angkatan di Fakultas Ilmu Sosial dan Ilmu '
          'Politik, boleh berkenalan dan bertukar kabar tentang peluang kerja?',
      status: const ['pending', 'accepted', 'declined'][i % 3],
    ),
];

List<Map<String, dynamic>> outgoingRows([int n = 9]) => [
  for (var i = 0; i < n; i++)
    outgoingMap(
      id: 'o$i',
      targetId: 'u$i',
      name: longName,
      status: const ['pending', 'accepted', 'declined'][i % 3],
    ),
];

List<Map<String, dynamic>> noteRows([int n = 9]) => [
  for (var i = 0; i < n; i++)
    {
      'id': 'n$i',
      'title': 'Permintaan kontak baru dari $longName',
      'body':
          'Muhammad Fajar Ramadhan Nugroho Wijayakusuma ingin terhubung '
          'dengan Anda melalui aplikasi Lingkaran alumni Undip.',
      'type': const [
        'contact_request_received',
        'business_approved',
        'report_new',
        'something_new',
      ][i % 4],
      'target_type': 'contact_request',
      'target_id': 'r$i',
      'job_post_id': null,
      'read_at': i.isEven ? null : '2026-10-02T09:00:00+00:00',
      'created_at': '2026-10-02T08:00:00+00:00',
    },
];

List<Map<String, dynamic>> reportRows([int n = 9]) => [
  for (var i = 0; i < n; i++)
    {
      'target_type': const ['job', 'product', 'business', 'profile'][i % 4],
      'target_id': 't$i',
      'title': 'Lowongan Staf Keuangan dan Akuntansi Senior PT Maju Bersama $i',
      'owner_id': 'o',
      'owner_name': longName,
      'report_count': 7,
      'reasons': [
        'spam_or_scam',
        'fake_or_impersonation',
        'wrong_info',
        'inappropriate',
        'other',
      ],
      'notes': [
        'Lowongan ini meminta biaya pendaftaran dan tidak mencantumkan alamat '
            'perusahaan yang jelas.',
      ],
      'last_reported': '2026-10-02T00:00:00Z',
      'is_hidden': i % 5 == 4,
      'hidden_reason': i % 5 == 4
          ? 'Terbukti palsu setelah diperiksa admin'
          : null,
    },
];

List<Map<String, dynamic>> feedbackRows([int n = 9]) => [
  for (var i = 0; i < n; i++)
    {
      'id': 'f$i',
      'profile_name': i == 2 ? null : longName,
      'message':
          'Saat membuka daftar bisnis aplikasi menutup sendiri dan saya harus '
          'membukanya lagi dari awal, mohon diperbaiki secepatnya.',
      'error_text':
          'Exception: Could not load the very long business directory list '
          'because the connection timed out after thirty seconds',
      'screen': 'Business directory screen of the market tab',
      'app_version': '0.9.0',
      'build_number': '7',
      'platform': 'android',
      'status': const ['new', 'seen', 'done'][i % 3],
      'created_at': '2026-10-02T08:00:00+00:00',
    },
];

List<Map<String, dynamic>> blockedRows([int n = 9]) => [
  for (var i = 0; i < n; i++)
    {
      'blocked_id': 'u$i',
      'name': longName,
      'created_at': '2026-10-01T00:00:00Z',
    },
];

List<Map<String, dynamic>> alumniRows([int n = 12]) => [
  {'id': 'me', 'name': longName, 'city': 'Semarang'},
  for (var i = 0; i < n; i++)
    {
      'id': 'a$i',
      'name': longName,
      'city': i % 3 == 0 ? longCity : (i % 3 == 1 ? 'Jakarta' : 'Bandung'),
      'current_role': 'Kepala Divisi Perencanaan dan Pengembangan Strategis',
      'faculty': longFaculty,
      'major': longMajor,
      'graduation_year': 2010 + i,
    },
];

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

class Variant {
  const Variant(this.name, this.size, this.scale);
  final String name;
  final Size size;
  final double scale;
}

const variants = [
  Variant('320x568 x1.0', Size(320, 568), 1.0),
  Variant('360x640 x1.6', Size(360, 640), 1.6),
];

/// Reads the policy files straight from disk.
class DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

typedef After = Future<void> Function(WidgetTester tester);

class Case {
  Case(this.name, this.build, {this.after, this.dark = false});
  final String name;
  final Widget Function() build;

  /// Runs after the first pump (for example opens a sheet).
  final After? after;
  final bool dark;
}

Widget wrap(Widget child, Variant v, {Key? key}) => MaterialApp(
  key: key,
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(v.scale)),
    child: c!,
  ),
  home: DefaultAssetBundle(bundle: DiskBundle(), child: child),
);

/// A page with a button that opens something (a sheet).
Widget launcher(void Function(BuildContext) open) => Scaffold(
  body: Builder(
    builder: (ctx) => Center(
      child: TextButton(
        key: const Key('launch'),
        onPressed: () => open(ctx),
        child: const Text('OPEN'),
      ),
    ),
  ),
);

Future<void> openLauncher(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('launch')));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  // pumpAndSettle can hang on endless animations (spinners): bounded pumps.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
}

Future<void> pumpCase(
  WidgetTester tester,
  Case c,
  Variant v, {
  required Key key,
}) async {
  tester.view.physicalSize = v.size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = c.dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(wrap(c.build(), v, key: key));
  await settle(tester);
  if (c.after != null) await c.after!(tester);
}

/// Scrolls every vertical scrollable to the end and back, so off-screen list
/// items are built and laid out too. Throws nothing; exceptions are read by
/// the caller with takeException.
Future<void> scrollAll(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  final n = scrollables.evaluate().length;
  for (var i = 0; i < n; i++) {
    final f = scrollables.at(i);
    if (!f.evaluate().isNotEmpty) continue;
    final state = tester.state<ScrollableState>(f);
    if (state.axisDirection != AxisDirection.down) continue;
    final pos = state.position;
    if (!pos.hasContentDimensions) continue;
    for (var step = 0; step < 40; step++) {
      final before = pos.pixels;
      pos.jumpTo(
        (before + 300).clamp(pos.minScrollExtent, pos.maxScrollExtent),
      );
      await tester.pump();
      if (pos.pixels == before) break;
    }
    pos.jumpTo(pos.minScrollExtent);
    await tester.pump();
  }
}

// ---------------------------------------------------------------------------
// Cases
// ---------------------------------------------------------------------------

Widget _bizDirectory(List<Map<String, dynamic>> rows, {Object? error}) {
  final api = FakeBusinessApi()..results['business_directory'] = rows;
  if (error != null) api.throwOnCall = error;
  return BusinessDirectoryScreen(
    currentUser: me,
    repository: BusinessRepository(api),
  );
}

Widget _myBiz(List<Map<String, dynamic>> rows, {Object? error}) {
  final api = FakeBusinessApi()
    ..results['business_my'] = rows
    ..results['business_my_usage'] = [
      for (var i = 0; i < rows.length; i++)
        {
          'business_id': 'b$i',
          'free_limit': 3,
          'used': 3,
          'unlimited_active': i % 2 == 0,
          'can_post': i % 2 == 0,
        },
    ];
  if (error != null) api.throwOnCall = error;
  return MyBusinessesScreen(ownerId: 'me', repository: BusinessRepository(api));
}

Widget _requests({int initialTab = 0, bool empty = false, Object? error}) {
  final api = FakeContactApi()
    ..results['contact_requests_incoming'] = empty
        ? <dynamic>[]
        : incomingRows()
    ..results['contact_requests_outgoing'] = empty
        ? <dynamic>[]
        : outgoingRows();
  if (error != null) api.throwOnCall = error;
  return RequestsScreen(
    currentUser: me,
    repository: ContactRepository(api),
    initialTab: initialTab,
  );
}

Widget _notifications(List<Map<String, dynamic>> rows, {Object? error}) {
  final api = _NoteApi(rows)..listError = error;
  return NotificationsScreen(
    currentUser: me,
    repository: NotificationRepository(api),
    buildPage: (d, n, user, job) => const Scaffold(),
  );
}

class _NoteApi implements NotificationApi {
  _NoteApi(this.rows);
  final List<Map<String, dynamic>> rows;
  Object? listError;
  @override
  Future<List<Map<String, dynamic>>> list(String recipientId) async {
    if (listError != null) throw listError!;
    return rows;
  }

  @override
  Future<int> unreadCount(String recipientId) async => 3;
  @override
  Future<void> markAllRead(String recipientId) async {}
  @override
  Future<Map<String, dynamic>?> job(String jobId) async => null;
}

Widget _adminReports(List<Map<String, dynamic>> rows, {Object? error}) {
  final api = FakeAdminApi()..results['admin_reports_list'] = rows;
  if (error != null) api.throwOnCall = error;
  return AdminReportsScreen(adminId: 'me', repository: AdminRepository(api));
}

Widget _adminFeedback(List<Map<String, dynamic>> rows, {Object? error}) {
  final api = FakeAdminApi()..results['admin_feedback_list'] = rows;
  if (error != null) api.throwOnCall = error;
  return AdminFeedbackScreen(adminId: 'me', repository: AdminRepository(api));
}

Widget _blocked(List<Map<String, dynamic>> rows, {Object? error}) {
  final api = FakeBlockApi()..results['user_blocks_list'] = rows;
  if (error != null) api.throwOnCall = error;
  return BlockedUsersScreen(
    currentUserId: 'me',
    repository: BlockRepository(api),
    blockList: BlockList.preloaded({
      for (final r in rows) r['blocked_id'] as String,
    }),
  );
}

Widget _marketplace({List<Map<String, dynamic>>? rows, Object? error}) {
  final api = FakeApi()..approved = rows ?? listingRows();
  if (error != null) api.throwOnCall = error;
  return MarketplaceScreen(
    currentUser: me,
    repository: MarketplaceRepository(api),
    businessRepository: BusinessRepository(
      FakeBusinessApi()..results['business_my'] = [bizRow(0)],
    ),
    showBack: true,
  );
}

Widget _market(int segment) => MarketScreen(
  currentUser: me,
  segment: ValueNotifier(segment),
  marketplaceRepository: MarketplaceRepository(
    FakeApi()..approved = listingRows(),
  ),
  businessRepository: BusinessRepository(
    FakeBusinessApi()..results['business_directory'] = approvedBizRows(),
  ),
);

Widget _home({
  bool badges = true,
  List<Business>? businesses,
  bool announcements = true,
}) {
  final api = FakeHomeApi(
    announcements: announcements
        ? [
            for (var i = 1; i <= 6; i++)
              {
                ...announcementMap(i),
                'title':
                    'Pengumuman penting reuni akbar alumni Universitas '
                    'Diponegoro angkatan 2010 sampai 2020 nomor $i',
                'body': longDesc,
                'posted_by': longName,
              },
          ]
        : const [],
    jobs: [
      for (var i = 1; i <= 6; i++)
        {
          ...jobMap(i),
          'title': 'Manajer Pengembangan Bisnis dan Kemitraan Strategis $i',
          'company': 'PT Pembangunan Jaya Sentosa Abadi Nusantara Raya',
        },
    ],
    pendingRequests: badges ? 12 : 0,
    unreadNotifications: badges ? 123 : 0,
    businesses: businesses ?? [Business.fromMap(bizRow(0, status: 'approved'))],
    usage: const [
      BusinessUsage(
        businessId: 'b0',
        freeLimit: 3,
        used: 3,
        unlimitedActive: false,
        canPost: false,
      ),
    ],
  );
  return HomeScreen(
    currentUser: me,
    onOpenDirectory: () {},
    pages: fakePages(),
    api: api,
    marketplaceRepository: MarketplaceRepository(
      FakeApi()..approved = listingRows(),
    ),
    autoAdvance: const Duration(days: 1),
  );
}

Future<void> _openFeedback(WidgetTester tester) => openLauncher(tester);

List<Case> buildCases() {
  final policyBundle = DiskBundle();
  return [
    Case('WelcomeScreen', () => const WelcomeScreen()),
    Case(
      'WelcomeScreen with notice',
      () => const WelcomeScreen(
        notice:
            'We could not sign you in on this device. Please check your '
            'university email and try again in a few minutes.',
      ),
    ),
    Case(
      'VerificationScreen (idle)',
      () => VerificationScreen(
        lock: makeLock(),
        verifyEmail: (e) async => testProfile(),
        accountRepository: AccountRepository(_NoopAccountApi()),
      ),
    ),
    Case(
      'ConsentScreen',
      () => ConsentScreen(
        profile: testProfile(policyVersion: null),
        onAccepted: (_, _) {},
        lock: makeLock(),
        repository: AccountRepository(_NoopAccountApi()),
        bundle: policyBundle,
      ),
    ),
    Case('PolicyScreen', () => PolicyScreen(bundle: policyBundle)),
    Case('AboutScreen', () {
      AppInfo.shared = const AppInfo(version: '0.9.0', buildNumber: '7');
      return const AboutScreen();
    }),
    Case('HomeScreen (badges, business card)', () => _home()),
    Case(
      'HomeScreen (no business, no announcements)',
      () => _home(badges: false, businesses: [], announcements: false),
    ),
    Case(
      'HomeShell',
      () => HomeShell(
        profile: {...me.value},
        pages: fakePages(),
        homeApi: FakeHomeApi(
          announcements: [announcementMap(1)],
          pendingRequests: 12,
          unreadNotifications: 123,
        ),
        marketplaceRepository: MarketplaceRepository(FakeApi()),
        chat: true,
      ),
    ),
    Case('MarketScreen products', () => _market(0)),
    Case('MarketScreen businesses', () => _market(1)),
    Case('BusinessDirectoryScreen', () => _bizDirectory(approvedBizRows())),
    Case('BusinessDirectoryScreen empty', () => _bizDirectory([])),
    Case(
      'BusinessDirectoryScreen error',
      () => _bizDirectory([], error: Exception('network')),
    ),
    Case(
      'BusinessFormScreen (create)',
      () => BusinessFormScreen(
        ownerId: 'me',
        repository: BusinessRepository(FakeBusinessApi()),
      ),
    ),
    Case('MyBusinessesScreen', () => _myBiz(bizRows())),
    Case('MyBusinessesScreen empty', () => _myBiz([])),
    Case(
      'MyBusinessesScreen error',
      () => _myBiz([], error: Exception('network')),
    ),
    Case('RequestsScreen received', () => _requests()),
    Case('RequestsScreen sent', () => _requests(initialTab: 1)),
    Case('RequestsScreen empty', () => _requests(empty: true)),
    Case('RequestsScreen error', () => _requests(error: Exception('x'))),
    Case('NotificationsScreen', () => _notifications(noteRows())),
    Case('NotificationsScreen empty', () => _notifications([])),
    Case(
      'NotificationsScreen error',
      () => _notifications([], error: Exception('x')),
    ),
    Case(
      'AdminScreen',
      () => AdminScreen(
        adminId: 'me',
        adminRepository: AdminRepository(FakeAdminApi()),
        marketplaceRepository: MarketplaceRepository(FakeApi()),
      ),
    ),
    Case('AdminReportsScreen', () => _adminReports(reportRows())),
    Case('AdminReportsScreen empty', () => _adminReports([])),
    Case(
      'AdminReportsScreen error',
      () => _adminReports([], error: Exception('x')),
    ),
    Case('AdminFeedbackScreen', () => _adminFeedback(feedbackRows())),
    Case('AdminFeedbackScreen empty', () => _adminFeedback([])),
    Case(
      'AdminFeedbackScreen error',
      () => _adminFeedback([], error: Exception('x')),
    ),
    Case('BlockedUsersScreen', () => _blocked(blockedRows())),
    Case('BlockedUsersScreen empty', () => _blocked([])),
    Case('BlockedUsersScreen error', () => _blocked([], error: Exception('x'))),
    Case(
      'DeleteAccountScreen',
      () => DeleteAccountScreen(
        currentUser: me,
        repository: AccountRepository(_NoopAccountApi()),
        lock: makeLock(),
        blockList: BlockList.preloaded({}),
      ),
    ),
    Case(
      'ProfileDetailScreen (own, admin)',
      () => ProfileDetailScreen(
        profile: {...me.value},
        currentUser: me,
        adminCheck: (_) async => true,
        chat: true,
        contactRepository: ContactRepository(FakeContactApi()),
      ),
    ),
    Case(
      'ProfileDetailScreen (other)',
      () => ProfileDetailScreen(
        profile: {...me.value, 'id': 'u9'},
        currentUser: me,
        showEditButton: false,
        chat: true,
        contactRepository: ContactRepository(FakeContactApi()),
      ),
    ),
    Case('MarketplaceScreen', () => _marketplace()),
    Case('MarketplaceScreen empty', () => _marketplace(rows: [])),
    Case(
      'MarketplaceScreen error',
      () => _marketplace(error: Exception('network')),
    ),
    Case(
      'MarketplaceFormScreen',
      () => MarketplaceFormScreen(
        sellerId: 'me',
        businessId: 'b0',
        repository: MarketplaceRepository(FakeApi()),
        defaultCity: longCity,
      ),
    ),
    Case(
      'NearbyAlumniScreen (list)',
      () => _nearby(
        currentUser: me,
        chat: true,
        fetchAlumni: () async => alumniRows(),
      ),
    ),
    Case(
      'NearbyAlumniScreen (map, light)',
      () => _nearby(
        currentUser: me,
        chat: true,
        fetchAlumni: () async => alumniRows(),
      ),
      after: _showMap,
    ),
    Case(
      'NearbyAlumniScreen (map, dark)',
      () => _nearby(
        currentUser: me,
        chat: true,
        fetchAlumni: () async => alumniRows(),
      ),
      after: _showMap,
      dark: true,
    ),
    Case(
      'NearbyAlumniScreen empty',
      () => _nearby(currentUser: me, fetchAlumni: () async => []),
    ),
    Case(
      'NearbyAlumniScreen error',
      () => _nearby(
        currentUser: me,
        fetchAlumni: () async => throw Exception('network'),
      ),
    ),
    Case(
      'ErrorView',
      () => const Scaffold(
        body: ErrorView(
          message:
              'We could not load this list right now. Please check your '
              'internet connection and try again in a moment.',
          screen: 'Stress',
        ),
      ),
    ),
    Case(
      'ErrorView with retry',
      () => Scaffold(
        body: ErrorView(
          message:
              'We could not load this list right now. Please check your '
              'internet connection and try again in a moment.',
          screen: 'Stress',
          onRetry: () {},
          retryLabel: 'Try again now please',
        ),
      ),
    ),
    Case(
      'Feedback sheet',
      () => launcher(
        (ctx) => showFeedbackSheet(
          ctx,
          error: Exception('a very long error text ' * 20),
          screen: 'Business directory screen of the market tab',
          repository: FeedbackRepository(_NoopFeedbackApi()),
          appInfo: const AppInfo(version: '0.9.0', buildNumber: '7'),
        ),
      ),
      after: _openFeedback,
    ),
    Case(
      'Report sheet (content)',
      () => launcher(
        (ctx) => showContentReportSheet(
          ctx,
          repository: ReportRepository(FakeReportApi()),
          reporterId: 'me',
          type: ReportTarget.business,
          targetId: 'b1',
          what: longBiz,
        ),
      ),
      after: openLauncher,
    ),
    Case(
      'Report sheet (marketplace)',
      () => launcher(
        (ctx) => showReportSheet(
          ctx,
          repository: MarketplaceRepository(FakeApi()),
          listingId: 'l1',
          reporterId: 'me',
        ),
      ),
      after: openLauncher,
    ),
    Case(
      'Request contact sheet',
      () => launcher(
        (ctx) => showRequestContactSheet(
          ctx,
          repository: ContactRepository(FakeContactApi()),
          requesterId: 'me',
          targetId: 'u2',
          targetName: longName,
        ),
      ),
      after: openLauncher,
    ),
  ];
}

Widget _nearby({
  required ValueNotifier<Map<String, dynamic>> currentUser,
  bool chat = false,
  required Future<List<Map<String, dynamic>>> Function() fetchAlumni,
}) => Scaffold(
  body: NearbyAlumniScreen(
    currentUser: currentUser,
    chat: chat,
    fetchAlumni: fetchAlumni,
  ),
);

Future<void> _showMap(WidgetTester tester) async {
  await tester.tap(find.text('Map'));
  await settle(tester);
}

class _NoopAccountApi implements AccountApi {
  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async => null;
  @override
  Future<List<String>> removeFiles(String bucket, List<String> paths) async =>
      paths;
}

class _NoopFeedbackApi implements FeedbackApi {
  @override
  Future<void> insert(Map<String, dynamic> row) async {}
}

// ---------------------------------------------------------------------------
// Tap target and label checks
// ---------------------------------------------------------------------------

const _minTap = 47.5; // 48 minus rounding noise

List<String> tapViolations(WidgetTester tester, String where) {
  final out = <String>[];
  void check(Finder f, String kind) {
    final els = f.evaluate().toList();
    for (var i = 0; i < els.length; i++) {
      final el = els[i];
      final ro = el.renderObject;
      if (ro is! RenderBox || !ro.hasSize || !ro.attached) continue;
      // Skip anything that is not on screen or not enabled.
      final w = el.widget;
      var enabled = true;
      if (w is ButtonStyleButton) enabled = w.enabled;
      if (w is IconButton) enabled = w.onPressed != null;
      if (w is ListTile) {
        enabled = w.enabled && (w.onTap != null || w.onLongPress != null);
      }
      if (!enabled) continue;
      final s = ro.size;
      if (s.width < _minTap || s.height < _minTap) {
        out.add(
          '$where: $kind ${_describe(el)} is ${s.width.toStringAsFixed(1)}x${s.height.toStringAsFixed(1)}',
        );
      }
    }
  }

  check(find.byType(IconButton), 'IconButton');
  check(find.byType(ListTile), 'ListTile');
  check(find.byType(FilledButton), 'FilledButton');
  check(find.byType(TextButton), 'TextButton');
  check(find.byType(OutlinedButton), 'OutlinedButton');

  // Icon-only IconButtons need a tooltip or a semantic label.
  for (final el in find.byType(IconButton).evaluate()) {
    final w = el.widget as IconButton;
    final icon = w.icon;
    final hasTooltip = (w.tooltip ?? '').isNotEmpty;
    final hasLabel = icon is Icon && (icon.semanticLabel ?? '').isNotEmpty;
    final hasSemantics = icon is Semantics || icon is Text;
    if (!hasTooltip && !hasLabel && !hasSemantics) {
      out.add(
        '$where: IconButton without tooltip/semanticLabel ${_describe(el)}',
      );
    }
  }
  return out;
}

String _describe(Element el) {
  final w = el.widget;
  String text = '';
  void find(Element e) {
    if (text.isNotEmpty) return;
    final ww = e.widget;
    if (ww is Text && ww.data != null) {
      text = '"${ww.data}"';
      return;
    }
    if (ww is Icon && ww.icon != null) {
      text = 'icon(${ww.icon!.codePoint.toRadixString(16)})';
      return;
    }
    e.visitChildren(find);
  }

  el.visitChildren(find);
  return '${w.runtimeType}${w.key != null ? ' ${w.key}' : ''} $text';
}

// ---------------------------------------------------------------------------

/// The default test font (Ahem) is a full em wide for every letter, about
/// twice as wide as real text. Load the Roboto files that ship with Flutter so
/// the widths are realistic.
Future<void> loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  var found = false;
  for (final f in ['Regular', 'Medium', 'Bold', 'Italic']) {
    final file = File('$dir/Roboto-$f.ttf');
    if (file.existsSync()) {
      found = true;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  if (found) await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRoboto);
  final cases = buildCases();

  group('layout stress', () {
    for (final v in variants) {
      for (final c in cases) {
        testWidgets('${c.name} @ ${v.name}', (tester) async {
          await pumpCase(tester, c, v, key: UniqueKey());
          var err = tester.takeException();
          await scrollAll(tester);
          err ??= tester.takeException();
          if (err != null) {
            final text = err is FlutterError ? err.toStringDeep() : '$err';
            final where = RegExp(r'file:///\S+')
                .allMatches(text)
                .map((m) => m.group(0))
                .toSet()
                .join(' ');
            fail(
              '${c.name} @ ${v.name}: ${text.split('\n').take(4).join(' ')} $where',
            );
          }
        });
      }
    }
  });

  testWidgets('tap targets and tooltips (all violations)', (tester) async {
    final all = <String>[];
    for (final v in variants) {
      for (final c in cases) {
        await pumpCase(tester, c, v, key: UniqueKey());
        tester.takeException();
        final where = '${c.name} @ ${v.name}';
        all.addAll(tapViolations(tester, where));
        // Also after scrolling to the end of each list.
        final before = all.length;
        final scrollables = find.byType(Scrollable);
        for (var i = 0; i < scrollables.evaluate().length; i++) {
          final state = tester.state<ScrollableState>(scrollables.at(i));
          if (state.axisDirection != AxisDirection.down) continue;
          final pos = state.position;
          if (!pos.hasContentDimensions) continue;
          while (true) {
            final b = pos.pixels;
            pos.jumpTo(
              (b + 400).clamp(pos.minScrollExtent, pos.maxScrollExtent),
            );
            await tester.pump();
            all.addAll(tapViolations(tester, where));
            if (pos.pixels == b) break;
          }
        }
        if (all.length == before) {
          // nothing new
        }
        tester.takeException();
      }
    }
    final unique = all.toSet().toList()..sort();
    for (final line in unique) {
      // ignore: avoid_print
      print('TAP VIOLATION: $line');
    }
    expect(unique, isEmpty, reason: '${unique.length} tap target violations');
  });

  testWidgets('Consent and My businesses survive 2x text on 320 wide', (
    tester,
  ) async {
    const v = Variant('320x568 x2.0', Size(320, 568), 2.0);
    for (final c in buildCases().where(
      (c) =>
          c.name == 'ConsentScreen' || c.name.startsWith('MyBusinessesScreen'),
    )) {
      await pumpCase(tester, c, v, key: UniqueKey());
      expect(tester.takeException(), isNull, reason: c.name);
    }
  });
}
