import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:undip_alumni_connect/data/industries.dart';
import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/contact_admin_screen.dart';
import 'package:undip_alumni_connect/widgets/sponsor_banner.dart';
import 'package:undip_alumni_connect/widgets/verified_badge.dart';

import 'support/fake_business_api.dart' show businessMap;
import 'home_screen_test.dart' show pumpHome;
import 'real_login_test.dart' show FakeLoginApi, pumpVerify;
import 'support/fake_home.dart';

const _intro =
    'Yuk isi database alumni terlebih dahulu sebelum mengakses Aplikasi '
    'Lingkaran. Setelah mengisi, mohon tunggu beberapa hari untuk kami '
    'melakukan verifikasi atas data yang kamu input';

void main() {
  group('industry list', () {
    test('has a creative industry, Other still last, no repeats', () {
      expect(kIndustries.any((i) => i.startsWith('Creative Industry')), isTrue);
      expect(kIndustries.last, 'Other');
      expect(kIndustries.toSet().length, kIndustries.length);
    });
  });

  group('sponsor carousel cap', () {
    testWidgets('shows at most 10 slides', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SponsorBanner(
              items: [for (var i = 1; i <= 12; i++) sponsorMap(i)],
              onOpen: (_) {},
              autoAdvance: const Duration(seconds: 3),
            ),
          ),
        ),
      );
      await tester.pump();
      final seen = <String>{};
      for (var i = 0; i < 12; i++) {
        for (var n = 1; n <= 12; n++) {
          if (find.textContaining('Sponsor $n').evaluate().isNotEmpty) {
            seen.add('$n');
          }
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(seen, {for (var n = 1; n <= 10; n++) '$n'});
    });
  });

  group('home business tick', () {
    testWidgets('owner card shows the blue tick when the NIB is verified', (
      tester,
    ) async {
      final b = Business.fromMap(
        businessMap(
          status: 'approved',
          reviewedAt: DateTime.now().toIso8601String(),
          nib: '1234567890123',
          nibVerified: true,
        ),
      );
      await pumpHome(tester, api: FakeHomeApi(businesses: [b]));
      expect(find.byType(VerifiedBadge, skipOffstage: false), findsOneWidget);
    });

    testWidgets('no tick when the NIB is not verified', (tester) async {
      final b = Business.fromMap(
        businessMap(
          status: 'approved',
          reviewedAt: DateTime.now().toIso8601String(),
        ),
      );
      await pumpHome(tester, api: FakeHomeApi(businesses: [b]));
      expect(find.byType(VerifiedBadge), findsNothing);
    });
  });

  group('Belum punya akun', () {
    testWidgets('the login link says Hubungi IKAFE', (tester) async {
      await pumpVerify(tester, FakeLoginApi());
      expect(find.text('Belum punya akun? Hubungi IKAFE'), findsOneWidget);
    });

    testWidgets('shows the QR code and the explanation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ContactAdminScreen(
            fromLogin: true,
            alumniFormUrl: 'https://forms.example.com/alumni',
          ),
        ),
      );
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(_intro), findsOneWidget);
      expect(find.byKey(const Key('alumni-form-open')), findsOneWidget);
    });

    testWidgets('no link filled in yet: no QR code, text still shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ContactAdminScreen(
            fromLogin: true,
            alumniFormUrl: '[FILL IN: link formulir]',
          ),
        ),
      );
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text(_intro), findsOneWidget);
    });

    testWidgets('the Profile contact screen has no QR code', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContactAdminScreen()));
      expect(find.byType(QrImageView), findsNothing);
    });
  });
}
