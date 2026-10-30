import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/ikafe_contact.dart';
import 'package:undip_alumni_connect/data/ikafe_contact_repository.dart';
import 'package:undip_alumni_connect/screens/admin_ikafe_contacts_screen.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/alumni_screen.dart';
import 'package:undip_alumni_connect/screens/home_pages.dart';
import 'package:undip_alumni_connect/screens/kontak_ikafe_screen.dart';

import 'support/fake_admin_api.dart';

Map<String, dynamic> row(
  String id,
  String kind,
  String label,
  String value, {
  int sort = 0,
  bool active = true,
}) => {
  'id': id,
  'kind': kind,
  'label': label,
  'value': value,
  'sort_order': sort,
  'active': active,
};

class FakeContactApi implements IkafeContactApi {
  FakeContactApi(this.rows, {this.error});
  final List<Map<String, dynamic>> rows;
  final Object? error;
  @override
  Future<List<Map<String, dynamic>>> activeRows() async {
    if (error != null) throw error!;
    return rows;
  }
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('IkafeContact', () {
    test('kinds are split into Hubungi and Media sosial', () {
      expect(IkafeContactKind.whatsapp.isSocial, isFalse);
      expect(IkafeContactKind.email.isSocial, isFalse);
      expect(IkafeContactKind.instagram.isSocial, isTrue);
      expect(IkafeContactKind.linkedin.isSocial, isTrue);
      expect(IkafeContactKind.website.isSocial, isTrue);
    });

    IkafeContact c(String kind, String value) =>
        IkafeContact.fromMap(row('x', kind, 'L', value));

    test('links open the right app', () {
      expect(
        c('whatsapp', '+62 812-3456').uri.toString(),
        'https://wa.me/628123456',
      );
      expect(c('email', 'a@b.id').uri.toString(), 'mailto:a@b.id');
      expect(
        c('instagram', '@ikafe').uri.toString(),
        'https://www.instagram.com/ikafe',
      );
      expect(
        c('instagram', 'https://instagram.com/ikafe').uri.host,
        'instagram.com',
      );
      expect(
        c('linkedin', 'linkedin.com/company/x').uri.toString(),
        'https://linkedin.com/company/x',
      );
      expect(c('website', 'ikafe.id').uri.toString(), 'https://ikafe.id');
    });

    test('unknown kind is skipped, not a crash', () {
      expect(IkafeContact.tryFromMap(row('x', 'fax', 'L', 'v')), isNull);
    });
  });

  group('repository', () {
    test('returns active rows in order', () async {
      final list = await IkafeContactRepository(
        FakeContactApi([
          row('b', 'email', 'Email', 'a@b.id', sort: 2),
          row('a', 'whatsapp', 'WhatsApp', '+6281', sort: 1),
        ]),
      ).load();
      expect(list.isPlaceholder, isFalse);
      expect(list.contacts.map((e) => e.id), ['a', 'b']);
    });

    test('a missing table falls back to marked placeholders', () async {
      final list = await IkafeContactRepository(
        FakeContactApi([], error: const IkafeTableMissing()),
      ).load();
      expect(list.isPlaceholder, isTrue);
      expect(list.contacts, isNotEmpty);
      for (final k in IkafeContactKind.values) {
        expect(list.contacts.any((e) => e.kind == k), isTrue, reason: '$k');
      }
    });

    test('any other error is not hidden', () async {
      expect(
        IkafeContactRepository(FakeContactApi([], error: Exception('x')))
            .load(),
        throwsException,
      );
    });
  });

  group('Kontak Ikafe screen', () {
    Future<void> pump(WidgetTester tester, IkafeContactApi api) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: KontakIkafeScreen(repository: IkafeContactRepository(api)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('two sections with their rows', (tester) async {
      await pump(
        tester,
        FakeContactApi([
          row('w', 'whatsapp', 'WhatsApp Ikafe', '+6281'),
          row('e', 'email', 'Email Ikafe', 'a@b.id'),
          row('i', 'instagram', 'Instagram', '@ikafe'),
          row('l', 'linkedin', 'LinkedIn', 'linkedin.com/company/x'),
          row('s', 'website', 'Website', 'ikafe.id'),
        ]),
      );
      expect(find.text('Kontak Ikafe'), findsWidgets);
      expect(find.byKey(const Key('ikafe-section-hubungi')), findsOneWidget);
      expect(find.byKey(const Key('ikafe-section-media')), findsOneWidget);
      expect(find.text('Hubungi'), findsOneWidget);
      expect(find.text('Media sosial'), findsOneWidget);
      for (final id in ['w', 'e', 'i', 'l', 's']) {
        expect(find.byKey(Key('ikafe-contact-$id')), findsOneWidget);
      }
      expect(find.byTooltip('Salin'), findsNWidgets(5));
      expect(find.textContaining('Contoh data'), findsNothing);
    });

    testWidgets('an empty section is hidden', (tester) async {
      await pump(
        tester,
        FakeContactApi([row('e', 'email', 'Email', 'a@b.id')]),
      );
      expect(find.byKey(const Key('ikafe-section-media')), findsNothing);
    });

    testWidgets('no rows at all says so', (tester) async {
      await pump(tester, FakeContactApi([]));
      expect(find.text('Belum ada kontak.'), findsOneWidget);
    });

    testWidgets('placeholder data is labelled', (tester) async {
      await pump(tester, FakeContactApi([], error: const IkafeTableMissing()));
      expect(find.textContaining('Contoh data'), findsOneWidget);
    });

    testWidgets('a failed load shows a retry', (tester) async {
      await pump(tester, FakeContactApi([], error: Exception('boom')));
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('failed open offers a copy action', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      await pump(
        tester,
        FakeContactApi([row('e', 'email', 'Email', 'a@b.id')]),
      );
      await tester.tap(find.byKey(const Key('ikafe-contact-e')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Tidak bisa dibuka'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Salin'), findsOneWidget);
    });
  });

  group('Home and Alumni', () {
    test('HomePages opens Kontak Ikafe, Nearby is gone', () {
      const pages = HomePages();
      final user = ValueNotifier<Map<String, dynamic>>({'id': 'me'});
      expect(pages.kontakIkafe(user), isA<KontakIkafeScreen>());
    });

    testWidgets('Alumni has no Nearby tab', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: AlumniScreen(currentUser: ValueNotifier({'id': 'me'})),
        ),
      );
      expect(find.text('Nearby'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
    });
  });

  group('admin repository', () {
    test('list parses rows', () async {
      final api = FakeAdminApi()
        ..results['admin_ikafe_contact_list'] = [
          row('a', 'email', 'Email', 'a@b.id', active: false),
        ];
      final list = await AdminRepository(api).ikafeContacts('me');
      expect(api.params['admin_ikafe_contact_list'], {'p_admin': 'me'});
      expect(list.single.active, isFalse);
    });

    test('save sends trimmed fields', () async {
      final api = FakeAdminApi();
      await AdminRepository(api).saveIkafeContact(
        'me',
        id: 'a',
        kind: IkafeContactKind.email,
        label: ' Email ',
        value: ' a@b.id ',
        sortOrder: 3,
        active: true,
      );
      expect(api.params['admin_ikafe_contact_save'], {
        'p_admin': 'me',
        'p_id': 'a',
        'p_kind': 'email',
        'p_label': 'Email',
        'p_value': 'a@b.id',
        'p_sort': 3,
        'p_active': true,
      });
    });

    test('delete sends the id', () async {
      final api = FakeAdminApi();
      await AdminRepository(api).deleteIkafeContact('me', 'a');
      expect(api.params['admin_ikafe_contact_delete'], {
        'p_admin': 'me',
        'p_id': 'a',
      });
    });
  });

  group('admin screens', () {
    Future<FakeAdminApi> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows,
    ) async {
      phone(tester);
      final api = FakeAdminApi()..results['admin_ikafe_contact_list'] = rows;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminIkafeContactsScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('Admin home lists Kontak Ikafe', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminScreen(
            adminId: 'me',
            adminRepository: AdminRepository(FakeAdminApi()),
          ),
        ),
      );
      expect(find.byKey(const Key('admin-ikafe-contacts')), findsOneWidget);
    });

    testWidgets('list shows hidden rows too', (tester) async {
      await pump(tester, [
        row('a', 'email', 'Email', 'a@b.id'),
        row('b', 'website', 'Website', 'ikafe.id', active: false),
      ]);
      expect(find.byKey(const Key('ikafe-admin-a')), findsOneWidget);
      expect(find.byKey(const Key('ikafe-admin-b')), findsOneWidget);
      expect(find.textContaining('Disembunyikan'), findsOneWidget);
    });

    testWidgets('empty form is refused without a call', (tester) async {
      final api = await pump(tester, []);
      await tester.tap(find.byKey(const Key('ikafe-contact-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ikafe-save')));
      await tester.pumpAndSettle();
      expect(find.text('Isi nama kontak.'), findsOneWidget);
      expect(find.text('Isi nilainya.'), findsOneWidget);
      expect(api.calls.contains('admin_ikafe_contact_save'), isFalse);
    });

    testWidgets('an email must have an @', (tester) async {
      final api = await pump(tester, []);
      await tester.tap(find.byKey(const Key('ikafe-contact-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('ikafe-label')), 'Email');
      await tester.enterText(
        find.byKey(const Key('ikafe-value')),
        'bukanemail',
      );
      await tester.tap(find.byKey(const Key('ikafe-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Email').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ikafe-save')));
      await tester.pumpAndSettle();
      expect(find.text('Isi email yang valid.'), findsOneWidget);
      expect(api.calls.contains('admin_ikafe_contact_save'), isFalse);
    });

    testWidgets('editing saves and reloads', (tester) async {
      final api = await pump(tester, [row('a', 'email', 'Email', 'a@b.id')]);
      await tester.tap(find.byKey(const Key('ikafe-admin-a')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('ikafe-value')), 'c@d.id');
      await tester.tap(find.byKey(const Key('ikafe-save')));
      await tester.pumpAndSettle();
      expect(api.params['admin_ikafe_contact_save']?['p_id'], 'a');
      expect(api.params['admin_ikafe_contact_save']?['p_value'], 'c@d.id');
      expect(api.calls.where((c) => c == 'admin_ikafe_contact_list').length, 2);
    });

    testWidgets('delete asks first, then calls', (tester) async {
      final api = await pump(tester, [row('a', 'email', 'Email', 'a@b.id')]);
      await tester.tap(find.byKey(const Key('ikafe-admin-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ikafe-delete')));
      await tester.pumpAndSettle();
      expect(api.calls.contains('admin_ikafe_contact_delete'), isFalse);
      await tester.tap(find.byKey(const Key('ikafe-delete-confirm')));
      await tester.pumpAndSettle();
      expect(api.params['admin_ikafe_contact_delete'], {
        'p_admin': 'me',
        'p_id': 'a',
      });
    });
  });
}
