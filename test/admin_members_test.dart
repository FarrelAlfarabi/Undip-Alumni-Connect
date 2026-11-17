import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/screens/admin_members_screen.dart';

import 'support/fake_admin_api.dart';

Map<String, dynamic> member({String bio = 'Bio lama'}) => {
  'id': 'm1',
  'name': 'Ahmad Ramadhan',
  'email': 'ahmad@example.com',
  'major': 'Manajemen',
  'graduation_year': 2020,
  'current_role': 'Analis',
  'industry': 'Perbankan',
  'company': 'Bank Contoh',
  'city': 'Semarang',
  'bio': bio,
  'linkedin_url': null,
};

void size(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<FakeAdminApi> open(WidgetTester tester, {Size? s}) async {
  size(tester, s ?? const Size(420, 1800));
  final api = FakeAdminApi()..results['admin_members_list'] = [member()];
  await tester.pumpWidget(
    MaterialApp(
      home: AdminMembersScreen(adminId: 'me', repository: AdminRepository(api)),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  test('repository sends the search and only the changed fields', () async {
    final api = FakeAdminApi()..results['admin_members_list'] = [member()];
    final repo = AdminRepository(api);
    final found = await repo.searchMembers('me', ' ahmad ');
    expect(api.params['admin_members_list'], {
      'p_admin': 'me',
      'p_search': 'ahmad',
    });
    expect(found.single.name, 'Ahmad Ramadhan');
    expect(found.single.bio, 'Bio lama');
    await repo.updateMember('me', 'm1', {'bio': 'Baru'});
    expect(api.params['admin_update_profile'], {
      'p_admin': 'me',
      'p_profile': 'm1',
      'p_changes': {'bio': 'Baru'},
    });
  });

  testWidgets('search and every filter narrow the list', (tester) async {
    size(tester, const Size(420, 1800));
    final api = FakeAdminApi()
      ..results['admin_members_list'] = [
        member(),
        {
          ...member(),
          'id': 'm2',
          'name': 'Siti Azizah',
          'email': 'siti@example.com',
          'major': 'Akuntansi',
          'graduation_year': 2018,
          'industry': 'Pendidikan',
          'company': 'Sekolah Nusa',
          'city': 'Jakarta',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: AdminMembersScreen(
          adminId: 'me',
          repository: AdminRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ahmad Ramadhan'), findsOneWidget);
    expect(find.text('Siti Azizah'), findsOneWidget);
    expect(find.byKey(const Key('members-count')), findsOneWidget);
    // Name, company and email all match the search.
    for (final q in ['siti', 'nusa', 'siti@example']) {
      await tester.enterText(find.byKey(const Key('members-search')), q);
      await tester.pumpAndSettle();
      expect(find.text('Ahmad Ramadhan'), findsNothing, reason: q);
      expect(find.text('Siti Azizah'), findsOneWidget, reason: q);
    }
    // Filters exist for major, year, industry and city; clear brings all back.
    expect(find.text('Major'), findsWidgets);
    expect(find.text('Year'), findsWidgets);
    expect(find.byKey(const Key('members-industry')), findsOneWidget);
    expect(find.text('City'), findsWidgets);
    await tester.enterText(find.byKey(const Key('members-search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada anggota yang cocok.'), findsOneWidget);
    await tester.tap(find.text('Hapus filter'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmad Ramadhan'), findsOneWidget);
    expect(find.text('Siti Azizah'), findsOneWidget);
    expect(api.calls.where((c) => c == 'admin_members_list').length, 1);
  });

  testWidgets('edit form shows name and email, never NIM', (tester) async {
    await open(tester);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    for (final k in [
      'member-role',
      'member-company',
      'member-industry',
      'member-city',
      'member-bio',
      'member-linkedin',
    ]) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.textContaining('NIM'), findsNothing);
    expect(find.byKey(const Key('member-email')), findsOneWidget);
    expect(find.byKey(const Key('member-name')), findsOneWidget);
  });

  testWidgets('changing the name sends only the name', (tester) async {
    final api = await open(tester);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-name')), 'Ahmad R.');
    await tester.ensureVisible(find.byKey(const Key('member-save')));
    await tester.tap(find.byKey(const Key('member-save')));
    await tester.pumpAndSettle();
    expect(api.params['admin_update_profile']!['p_changes'], {
      'name': 'Ahmad R.',
    });
  });

  testWidgets('changing the email asks first and sends it in lower case', (
    tester,
  ) async {
    final api = await open(tester);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('member-email')),
      'Ahmad.Baru@Example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('member-save')));
    await tester.tap(find.byKey(const Key('member-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('member-email-confirm')), findsOneWidget);
    expect(api.calls, isNot(contains('admin_update_profile')));
    await tester.tap(find.byKey(const Key('member-email-confirm-yes')));
    await tester.pumpAndSettle();
    expect(api.params['admin_update_profile']!['p_changes'], {
      'email': 'ahmad.baru@example.com',
    });
  });

  testWidgets('a bad email or a short name is refused on screen', (
    tester,
  ) async {
    final api = await open(tester);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('member-email')),
      'bukan-email',
    );
    await tester.ensureVisible(find.byKey(const Key('member-save')));
    await tester.tap(find.byKey(const Key('member-save')));
    await tester.pumpAndSettle();
    expect(find.text('Tulis email yang benar.'), findsOneWidget);
    expect(api.calls, isNot(contains('admin_update_profile')));
  });

  testWidgets('a taken email shows a plain sentence', (tester) async {
    final api = await open(tester);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('member-email')),
      'siti@example.com',
    );
    api.throwOnCall = const AdminException(
      AdminErrorCode.emailTaken,
      'email_taken',
    );
    await tester.ensureVisible(find.byKey(const Key('member-save')));
    await tester.tap(find.byKey(const Key('member-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-email-confirm-yes')));
    await tester.pumpAndSettle();
    expect(find.text('Email ini sudah dipakai anggota lain.'), findsOneWidget);
  });

  testWidgets('save sends only what changed', (tester) async {
    final api = await open(tester);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-bio')), 'Bio baru');
    await tester.enterText(
      find.byKey(const Key('member-linkedin')),
      'linkedin.com/in/ahmad',
    );
    await tester.ensureVisible(find.byKey(const Key('member-save')));
    await tester.tap(find.byKey(const Key('member-save')));
    await tester.pumpAndSettle();
    expect(api.params['admin_update_profile'], {
      'p_admin': 'me',
      'p_profile': 'm1',
      'p_changes': {'bio': 'Bio baru', 'linkedin_url': 'linkedin.com/in/ahmad'},
    });
    expect(find.text('Data anggota tersimpan.'), findsOneWidget);
  });

  testWidgets('a database refusal shows a plain Indonesian sentence', (
    tester,
  ) async {
    final api = await open(tester);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-bio')), 'Bio baru');
    api.throwOnCall = const AdminException(
      AdminErrorCode.invalidInput,
      'invalid_input',
    );
    await tester.ensureVisible(find.byKey(const Key('member-save')));
    await tester.tap(find.byKey(const Key('member-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('member-error')), findsOneWidget);
    expect(find.textContaining('invalid_input'), findsNothing);
  });

  testWidgets('bio field stops at 200 characters', (tester) async {
    await open(tester);
    await tester.tap(find.text('Ahmad Ramadhan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-bio')), 'a' * 250);
    final field = tester.widget<TextField>(find.byKey(const Key('member-bio')));
    expect(field.controller!.text.length, 200);
  });

  for (final s in [const Size(420, 800), const Size(1440, 900)]) {
    testWidgets('edit form fits ${s.width.toInt()} px wide', (tester) async {
      await open(tester, s: s);
      await tester.tap(find.text('Ahmad Ramadhan'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
