import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/support_config.dart';
import 'package:undip_alumni_connect/screens/contact_admin_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';

import 'real_login_test.dart' show FakeLoginApi, pumpVerify, settle;

Future<void> toCodeStep(WidgetTester tester, FakeLoginApi api) async {
  await pumpVerify(tester, api);
  await tester.enterText(find.byKey(const Key('login-email')), 'a@example.com');
  await tester.tap(find.text('Kirim kode'));
  await settle(tester);
}

void main() {
  group('Welcome copy', () {
    testWidgets('new headline and subline', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
      expect(
        find.textContaining(
          'Jejaring alumni FEB Undip untuk saling terhubung, berbagi '
          'peluang, dan tumbuh bersama',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('dukung usaha alumni, dan rekomendasikan lowongan'),
        findsOneWidget,
      );
    });
  });

  group('email step', () {
    testWidgets('one contact link, no card before anyone types', (
      tester,
    ) async {
      await pumpVerify(tester, FakeLoginApi());
      expect(find.byKey(const Key('login-contact-admin')), findsOneWidget);
      expect(find.text('Belum terdaftar? Hubungi tim admin'), findsOneWidget);
      expect(find.textContaining('lupa email yang dipakai?'), findsNothing);
      expect(find.text('Email tidak terdaftar'), findsNothing);
    });

    testWidgets('the contact link opens the contact screen with the intro', (
      tester,
    ) async {
      await pumpVerify(tester, FakeLoginApi());
      await tester.tap(find.byKey(const Key('login-contact-admin')));
      await tester.pumpAndSettle();
      expect(find.byType(ContactAdminScreen), findsOneWidget);
      expect(find.textContaining('Input nama lengkap'), findsOneWidget);
    });

    testWidgets('unknown email: inline error, contact link, other email', (
      tester,
    ) async {
      final api = FakeLoginApi(known: false);
      await pumpVerify(tester, api);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'nobody@example.com',
      );
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      expect(api.sent, isEmpty);
      expect(find.text('Email tidak terdaftar'), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.byKey(const Key('login-contact-admin')), findsOneWidget);
      expect(find.byKey(const Key('login-change-email')), findsOneWidget);
      await tester.tap(find.byKey(const Key('login-change-email')));
      await tester.pump();
      expect(find.text('Email tidak terdaftar'), findsNothing);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
    });

    testWidgets('no overflow at text scale 1.3 with the error showing', (
      tester,
    ) async {
      final api = FakeLoginApi(known: false);
      await pumpVerify(tester, api);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.enterText(find.byKey(const Key('login-email')), 'x@y.com');
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('code step', () {
    testWidgets('login-help is the outlined contact button', (tester) async {
      await toCodeStep(tester, FakeLoginApi());
      expect(find.byKey(const Key('login-help')), findsOneWidget);
      expect(find.text('Hubungi tim admin'), findsOneWidget);
      expect(find.byKey(const Key('login-resend')), findsOneWidget);
      expect(find.byKey(const Key('login-change-email')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('login-help')));
      await tester.tap(find.byKey(const Key('login-help')));
      await tester.pumpAndSettle();
      expect(find.byType(ContactAdminScreen), findsOneWidget);
    });
  });

  group('dead ends', () {
    testWidgets('no profile after a correct code: contact button, stop icon', (
      tester,
    ) async {
      final api = FakeLoginApi()..profile = null;
      await toCodeStep(tester, api);
      await tester.enterText(find.byKey(const Key('login-code')), '123456');
      await settle(tester);
      expect(find.text('Data Tidak Ditemukan'), findsOneWidget);
      expect(find.byKey(const Key('login-contact-admin')), findsOneWidget);
      expect(find.byIcon(Icons.person_search_outlined), findsNothing);
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
      expect(find.textContaining('hubungi tim admin'), findsOneWidget);
    });

    testWidgets('suspended: Indonesian title, Kembali, contact button', (
      tester,
    ) async {
      final api = FakeLoginApi()..verifyError = Exception('account_suspended');
      await toCodeStep(tester, api);
      await tester.enterText(find.byKey(const Key('login-code')), '123456');
      await settle(tester);
      expect(find.byKey(const Key('account-suspended')), findsOneWidget);
      expect(find.text('Akun ditangguhkan'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);
      expect(find.text('Account Suspended'), findsNothing);
      expect(find.byKey(const Key('login-contact-admin')), findsOneWidget);
    });

    testWidgets('error screen says Kirim masukan', (tester) async {
      final api = FakeLoginApi()..known = true;
      await pumpVerify(tester, api);
      api.emailKnownError = Exception('boom');
      await tester.enterText(find.byKey(const Key('login-email')), 'a@b.com');
      await tester.tap(find.text('Kirim kode'));
      await settle(tester);
      expect(find.text('Terjadi Kesalahan'), findsOneWidget);
      expect(find.text('Kirim masukan'), findsOneWidget);
      expect(find.text('Send feedback'), findsNothing);
    });
  });

  group('ContactAdminScreen', () {
    testWidgets('Indonesian, with the normal intro in Profile', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContactAdminScreen()));
      expect(find.text('Kontak admin'), findsOneWidget);
      expect(find.textContaining('Input nama lengkap'), findsNothing);
      expect(find.byTooltip('Salin'), findsWidgets);
    });

    testWidgets('fromLogin intro', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ContactAdminScreen(fromLogin: true)),
      );
      expect(find.textContaining('Input nama lengkap'), findsOneWidget);
    });

    testWidgets('a failed open offers a copy action', (tester) async {
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
      await tester.pumpWidget(const MaterialApp(home: ContactAdminScreen()));
      await tester.tap(find.byKey(const Key('support-email')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Tidak bisa dibuka'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Salin'), findsOneWidget);
    });

    test('mailto carries a subject and the typed email', () {
      const c = SupportContact(SupportContactKind.email, 'Email', 'a@b.id');
      final u = c.uriWith(subject: 'Verifikasi alumni Lingkaran', body: 'x');
      expect(u.scheme, 'mailto');
      expect(u.queryParameters['subject'], 'Verifikasi alumni Lingkaran');
      expect(u.queryParameters['body'], 'x');
      expect(c.uri.query, isEmpty);
    });

    test('loginMailBody uses the typed email only when there is one', () {
      expect(loginMailBody('a@b.id'), 'Email yang saya pakai: a@b.id');
      expect(loginMailBody(''), isNull);
    });
  });
}
