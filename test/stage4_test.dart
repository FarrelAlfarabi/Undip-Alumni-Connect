import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';
import 'package:undip_alumni_connect/data/profile_columns.dart';
import 'package:undip_alumni_connect/data/profile_fields.dart';
import 'package:undip_alumni_connect/data/report_repository.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';
import 'package:undip_alumni_connect/screens/profile_bio_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/screens/profile_linkedin_screen.dart';
import 'package:undip_alumni_connect/screens/requests_screen.dart';
import 'package:undip_alumni_connect/theme.dart';

import 'support/fake_contact_api.dart';

const me = {'id': 'me', 'name': 'Ahmad Ramadhan', 'nim': '12010120'};
const other = {
  'id': 'u2',
  'name': 'Rani Putri',
  'faculty': 'Ekonomika dan Bisnis',
  'major': 'Akuntansi',
  'graduation_year': 2018,
  'current_role': 'Business Analyst',
  'company': 'Bank Mandiri',
  'industry': 'Banking and Finance',
  'bio': 'Suka diskusi karier dan analisis data.',
  'linkedin_url': 'https://www.linkedin.com/in/ranip',
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpProfile(
  WidgetTester tester,
  Map<String, dynamic> profile, {
  bool own = false,
}) async {
  phone(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: ProfileDetailScreen(
        profile: profile,
        currentUser: ValueNotifier(
          Map<String, dynamic>.from(own ? profile : me),
        ),
        showEditButton: own,
        chat: false,
        contactRepository: ContactRepository(FakeContactApi()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('LinkedIn link', () {
    test('empty clears it', () {
      expect(normalizeLinkedInUrl('   '), isNull);
    });
    test('adds https and keeps linkedin.com links', () {
      expect(
        normalizeLinkedInUrl('linkedin.com/in/namamu'),
        'https://linkedin.com/in/namamu',
      );
      expect(
        normalizeLinkedInUrl(' https://www.linkedin.com/in/x '),
        'https://www.linkedin.com/in/x',
      );
    });
    test('refuses other sites, schemes and lookalikes', () {
      for (final bad in [
        'https://evil.example.com/in/x',
        'javascript:alert(1)',
        'http://linkedin.com/in/x',
        'https://linkedin.com.evil.com/in/x',
        'https://notlinkedin.com/in/x',
      ]) {
        expect(
          () => normalizeLinkedInUrl(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
    test('refuses over 200 characters', () {
      expect(
        () => normalizeLinkedInUrl('linkedin.com/in/${'a' * 200}'),
        throwsFormatException,
      );
    });
  });

  test('the profile columns list asks for bio and linkedin_url', () {
    expect(kProfileColumns, contains('bio'));
    expect(kProfileColumns, contains('linkedin_url'));
  });

  group('Profile detail', () {
    testWidgets('others see Bio and LinkedIn when filled', (tester) async {
      await pumpProfile(tester, other);
      expect(
        find.text('Suka diskusi karier dan analisis data.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profile-linkedin')), findsOneWidget);
      expect(find.byKey(const Key('edit-bio')), findsNothing);
      expect(find.byKey(const Key('edit-linkedin')), findsNothing);
    });

    testWidgets('others see nothing for an empty Bio and LinkedIn', (
      tester,
    ) async {
      await pumpProfile(tester, {...other, 'bio': null, 'linkedin_url': null});
      expect(find.byKey(const Key('profile-bio')), findsNothing);
      expect(find.byKey(const Key('profile-linkedin')), findsNothing);
    });

    testWidgets('my own profile offers Ubah even when empty', (tester) async {
      await pumpProfile(tester, {
        ...other,
        'bio': null,
        'linkedin_url': null,
      }, own: true);
      expect(find.byKey(const Key('edit-bio')), findsOneWidget);
      expect(find.byKey(const Key('edit-linkedin')), findsOneWidget);
    });
  });

  group('Bio screen', () {
    testWidgets('warns, counts to 200 and saves the trimmed text', (
      tester,
    ) async {
      phone(tester);
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ProfileBioScreen(
            profile: const {'id': 'me', 'bio': null},
            save: (id, changes) async {
              sent = changes;
              return {'id': id, ...changes};
            },
          ),
        ),
      );
      expect(
        find.textContaining('Dilarang menulis kata kasar'),
        findsOneWidget,
      );
      expect(find.text('0/200'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('bio-field')),
        '  Halo dunia  ',
      );
      await tester.pump();
      expect(find.text('14/200'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(sent, {'bio': 'Halo dunia'});
    });

    testWidgets('stops typing at 200 characters', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ProfileBioScreen(
            profile: const {'id': 'me'},
            save: (id, changes) async => {'id': id},
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('bio-field')), 'a' * 250);
      await tester.pump();
      expect(find.text('200/200'), findsOneWidget);
    });

    testWidgets('an empty Bio clears it', (tester) async {
      phone(tester);
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ProfileBioScreen(
            profile: const {'id': 'me', 'bio': 'Lama'},
            save: (id, changes) async {
              sent = changes;
              return {'id': id};
            },
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('bio-field')), '   ');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(sent, {'bio': null});
    });

    testWidgets('a failed save shows a message and stays', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ProfileBioScreen(
            profile: const {'id': 'me'},
            save: (id, changes) async => throw Exception('x'),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('bio-field')), 'Halo');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bio-error')), findsOneWidget);
      expect(find.byType(ProfileBioScreen), findsOneWidget);
    });

    testWidgets('a save that stored nothing shows a message and stays', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ProfileBioScreen(
            profile: const {'id': 'me'},
            save: (id, changes) async => null,
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('bio-field')), 'Halo');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bio-error')), findsOneWidget);
      expect(find.byType(ProfileBioScreen), findsOneWidget);
    });

    // The database counts code points; one flag emoji is 2 of them.
    testWidgets('counts like the database, so emoji cannot pass the limit', (
      tester,
    ) async {
      phone(tester);
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ProfileBioScreen(
            profile: const {'id': 'me'},
            save: (id, changes) async {
              called = true;
              return {'id': id, ...changes};
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('bio-field')),
        '\u{1F1EE}\u{1F1E9}' * 150,
      );
      await tester.pump();
      final text = tester
          .widget<TextField>(find.byKey(const Key('bio-field')))
          .controller!
          .text;
      expect(text.runes.length, lessThanOrEqualTo(kBioMax));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });

  group('LinkedIn screen', () {
    Future<void> pumpIt(
      WidgetTester tester,
      Future<Map<String, dynamic>?> Function(String, Map<String, dynamic>) save,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ProfileLinkedInScreen(profile: const {'id': 'me'}, save: save),
        ),
      );
    }

    testWidgets('saves the cleaned link', (tester) async {
      Map<String, dynamic>? sent;
      await pumpIt(tester, (id, c) async {
        sent = c;
        return {'id': id, ...c};
      });
      await tester.enterText(
        find.byKey(const Key('linkedin-field')),
        'linkedin.com/in/namamu',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(sent, {'linkedin_url': 'https://linkedin.com/in/namamu'});
    });

    testWidgets('refuses a link to another site and saves nothing', (
      tester,
    ) async {
      var called = false;
      await pumpIt(tester, (id, c) async {
        called = true;
        return {'id': id};
      });
      await tester.enterText(
        find.byKey(const Key('linkedin-field')),
        'https://evil.example.com/x',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(called, isFalse);
      expect(find.byKey(const Key('linkedin-error')), findsOneWidget);
    });
  });

  group('Chips', () {
    testWidgets('selected is black with white text, unselected is white', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Row(
              children: [
                ChoiceChip(
                  key: const Key('on'),
                  label: const Text('Aktif'),
                  selected: true,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  key: const Key('off'),
                  label: const Text('Lain'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      final theme = AppTheme.light().chipTheme;
      expect(theme.selectedColor, AppTheme.black);
      expect(theme.backgroundColor, AppTheme.paperRaised);
      expect(theme.side?.color, AppTheme.hairline);
      final onLabel = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(const Key('on')),
          matching: find.byType(RichText),
        ),
      );
      expect(onLabel.text.style?.color, Colors.white);
      final size = tester.getSize(find.byKey(const Key('off')));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('Cards', () {
    test('the card theme is white, hairline, radius 16, no shadow', () {
      final c = AppTheme.light().cardTheme;
      expect(c.elevation, 0);
      expect(c.color, AppTheme.paperRaised);
      final shape = c.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
      expect(shape.side.color, AppTheme.hairline);
    });
  });

  group('Indonesian copy', () {
    test('report reasons are Indonesian', () {
      expect(ContentReportReason.spamOrScam.labelId, 'Spam atau penipuan');
      expect(ContentReportReason.inappropriate.labelId, 'Tidak pantas');
      expect(
        ContentReportReason.fakeOrImpersonation.labelId,
        'Berpura-pura jadi orang lain',
      );
      expect(ContentReportReason.wrongInfo.labelId, 'Informasi salah');
      expect(ContentReportReason.other.labelId, 'Lainnya');
    });

    testWidgets('Requests screen words', (tester) async {
      phone(tester);
      final api = FakeContactApi()
        ..results['contact_requests_incoming'] = [incomingMap()]
        ..results['contact_requests_outgoing'] = [
          outgoingMap(status: 'accepted'),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: RequestsScreen(
            currentUser: ValueNotifier(Map<String, dynamic>.from(me)),
            repository: ContactRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Terima'), findsOneWidget);
      expect(find.text('Tolak'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
      await tester.tap(find.text('Terkirim'));
      await tester.pumpAndSettle();
      expect(find.text('Lihat daftar kontak'), findsOneWidget);
    });
  });

  group('Members list', () {
    testWidgets('a LinkedIn button shows only for people who added one', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DirectoryScreen(
              currentUser: ValueNotifier(Map<String, dynamic>.from(me)),
              fetchAlumni: () async => [
                {...other, 'id': 'a1', 'name': 'Rani Putri'},
                {
                  ...other,
                  'id': 'a2',
                  'name': 'Dewi Lestari',
                  'linkedin_url': null,
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('member-linkedin-a1')), findsOneWidget);
      expect(find.byKey(const Key('member-linkedin-a2')), findsNothing);
    });
  });
}
