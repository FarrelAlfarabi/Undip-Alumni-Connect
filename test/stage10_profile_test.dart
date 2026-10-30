import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/lock/pin_settings_screen.dart';
import 'package:undip_alumni_connect/screens/admin_reports_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/screens/settings_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_lock.dart';

/// Stage 10: Profil, Pengaturan, Akun (plan G1 to G5) and admin Hapus bio.
const me = {'id': 'me', 'name': 'Ahmad Ramadhan', 'email': 'a@example.com'};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpProfile(
  WidgetTester tester, {
  required Map<String, dynamic> shown,
}) async {
  phone(tester);
  final lock = await makeRememberedLock();
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileDetailScreen(
        profile: shown,
        currentUser: ValueNotifier<Map<String, dynamic>>({...me}),
        showEditButton: shown['id'] == me['id'],
        chat: false,
        adminCheck: (_) async => false,
        lock: lock,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Iterable<String> allTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

void main() {
  group('G1: profile menu', () {
    testWidgets('one grouped list: Akun, Pengaturan, Bantuan, Privasi', (
      tester,
    ) async {
      await pumpProfile(tester, shown: me);
      expect(find.byKey(const Key('profile-menu-account')), findsOneWidget);
      expect(find.text('Akun'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Bantuan'), findsOneWidget);
      expect(find.text('Kebijakan Privasi dan Ketentuan'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Help'), findsNothing);
      // The three rows sit in the same group, in this order.
      final group = find.byKey(const Key('profile-menu-account'));
      for (final key in [
        'profile-settings',
        'profile-help',
        'profile-policy',
      ]) {
        expect(
          find.descendant(of: group, matching: find.byKey(Key(key))),
          findsOneWidget,
        );
      }
      final y = [
        for (final k in ['profile-settings', 'profile-help', 'profile-policy'])
          tester.getTopLeft(find.byKey(Key(k))).dy,
      ];
      expect(y[0] < y[1] && y[1] < y[2], isTrue);
    });

    testWidgets('the Settings row has a gear icon', (tester) async {
      await pumpProfile(tester, shown: me);
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-settings')),
          matching: find.byIcon(Icons.settings_outlined),
        ),
        findsOneWidget,
      );
    });
  });

  group('G4/G5: Pengaturan in Indonesian', () {
    Future<void> openSettings(WidgetTester tester) async {
      phone(tester);
      final lock = await makeRememberedLock();
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            currentUser: ValueNotifier<Map<String, dynamic>>({...me}),
            lock: lock,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('title, rows and the account section use the agreed words', (
      tester,
    ) async {
      await openSettings(tester);
      final texts = allTexts(tester).toList();
      for (final want in [
        'Pengaturan',
        'Default kontak untuk dibagikan',
        'Terisi ketika menerima request',
        'Pengenalan fitur',
        'PIN',
        'Blokir pengguna',
        'Zona bahaya',
        'Hapus akun saya',
      ]) {
        expect(texts, contains(want), reason: want);
      }
      for (final gone in [
        'Settings',
        'PIN lock',
        'Blocked users',
        'Danger zone',
        'Delete my account',
        'Default contact to share',
      ]) {
        expect(texts, isNot(contains(gone)), reason: gone);
      }
      // Pengenalan fitur is easy to find: it is on the first screen.
      expect(find.byKey(const Key('settings-intro')), findsOneWidget);
    });

    testWidgets('PIN screen: Atur PIN, and no "lock" word', (tester) async {
      phone(tester);
      final lock = await makeRememberedLock(withPin: false);
      await tester.pumpWidget(MaterialApp(home: PinSettingsScreen(lock: lock)));
      await tester.pumpAndSettle();
      final texts = allTexts(tester).toList();
      expect(texts, contains('PIN'));
      expect(texts, contains('Atur PIN'));
      expect(texts.where((t) => t.toLowerCase().contains('lock')), isEmpty);
    });

    testWidgets('PIN screen with a PIN: Ubah PIN and Hapus PIN', (
      tester,
    ) async {
      phone(tester);
      final lock = await makeRememberedLock();
      await tester.pumpWidget(MaterialApp(home: PinSettingsScreen(lock: lock)));
      await tester.pumpAndSettle();
      final texts = allTexts(tester).toList();
      expect(texts, containsAll(['Ubah PIN', 'Hapus PIN']));
      expect(texts.where((t) => t.toLowerCase().contains('lock')), isEmpty);
    });
  });

  group('admin: Hapus bio', () {
    Map<String, dynamic> row(String type, String id) => {
      'target_type': type,
      'target_id': id,
      'title': 'Budi',
      'owner_id': 'o',
      'owner_name': 'Budi',
      'report_count': 1,
      'reasons': ['inappropriate'],
      'notes': <String>[],
      'last_reported': DateTime.now().toUtc().toIso8601String(),
      'is_hidden': false,
      'hidden_reason': null,
    };

    Future<FakeAdminApi> pump(WidgetTester tester, List rows) async {
      phone(tester);
      final api = FakeAdminApi()..results['admin_reports_list'] = rows;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportsScreen(
            adminId: 'adm',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('only a reported profile has Hapus bio', (tester) async {
      await pump(tester, [row('profile', 'u1'), row('job', 'j1')]);
      expect(find.byKey(const Key('clear-bio-u1')), findsOneWidget);
      expect(find.byKey(const Key('clear-bio-j1')), findsNothing);
      expect(find.text('Hapus bio'), findsOneWidget);
    });

    testWidgets('it asks first, then clears only the bio', (tester) async {
      final api = await pump(tester, [row('profile', 'u1')]);
      await tester.tap(find.byKey(const Key('clear-bio-u1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Akun tidak ikut dihapus'), findsOneWidget);
      expect(api.calls.contains('admin_clear_bio'), isFalse);
      await tester.tap(find.byKey(const Key('clear-bio-confirm')));
      await tester.pumpAndSettle();
      expect(api.params['admin_clear_bio'], {
        'p_admin': 'adm',
        'p_profile': 'u1',
      });
    });
  });
}
