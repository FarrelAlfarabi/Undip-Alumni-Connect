// "url tidak valid" on the CV button (Natasya, 24 Nov 2026): the CV link is a
// signed storage link whose token makes it far longer than the 500 letters
// allowed for a link a person types. The link check refused it, so the CV
// never opened. A link the app made itself keeps a larger limit; typed links
// (LinkedIn, portfolio) keep 500.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/util/safe_url.dart';
import 'package:undip_alumni_connect/widgets/safe_link_chip.dart';

// Same shape as createSignedUrl returns: host, sign path, long token.
String signedCvUrl({int tokenLength = 520}) =>
    'https://kdmxgtwqqnlbgfcpdivp.supabase.co/storage/v1/object/sign/cvs/'
    '0d4f6a52-9a3e-4c1c-8f0e-3c1a9d2b7e11/1764000000000_CV_Satriyo.pdf'
    '?token=${'a' * tokenLength}';

void main() {
  test('a signed CV link is longer than a link a person types', () {
    expect(signedCvUrl().length, greaterThan(kMaxUrlLength));
  });

  test('typed links still stop at 500 letters', () {
    expect(parseHttpUrl(signedCvUrl()), isNull);
    expect(parseHttpUrl('https://linkedin.com/in/${'a' * 600}'), isNull);
  });

  test('a link the app made may be long, but still only http(s)', () {
    final url = signedCvUrl();
    expect(parseHttpUrl(url, maxLength: kMaxSignedUrlLength), isNotNull);
    expect(
      parseHttpUrl('javascript:alert(1)', maxLength: kMaxSignedUrlLength),
      isNull,
    );
    expect(
      parseHttpUrl(
        'https://x.supabase.co/${'a' * (kMaxSignedUrlLength + 1)}',
        maxLength: kMaxSignedUrlLength,
      ),
      isNull,
    );
  });

  Future<List<Uri>> tapChip(
    WidgetTester tester,
    SafeLinkChip Function(UrlLauncher) chip,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: chip((u) async {
            opened.add(u);
            return true;
          }),
        ),
      ),
    );
    await tester.tap(find.byType(ActionChip));
    await tester.pump();
    return opened;
  }

  testWidgets('the CV chip opens a long signed link', (tester) async {
    final url = signedCvUrl();
    final opened = await tapChip(
      tester,
      (l) => SafeLinkChip(
        icon: Icons.description_outlined,
        label: 'CV',
        url: url,
        maxLength: kMaxSignedUrlLength,
        launcher: l,
      ),
    );
    expect(opened.single.toString(), url);
  });

  testWidgets('the LinkedIn chip still refuses an over long link', (
    tester,
  ) async {
    final opened = await tapChip(
      tester,
      (l) => SafeLinkChip(
        icon: Icons.link,
        label: 'LinkedIn',
        url: 'https://linkedin.com/in/${'a' * 600}',
        launcher: l,
      ),
    );
    expect(opened, isEmpty);
    expect(find.textContaining('tidak valid'), findsNothing); // passthrough
    expect(find.byType(SnackBar), findsOneWidget);
  });

  test('the applicants screen gives the CV chip the larger limit', () {
    final src = File('lib/screens/job_applicants_screen.dart')
        .readAsStringSync();
    final cv = src.indexOf("label: 'CV'");
    expect(cv, greaterThan(0));
    expect(
      src.substring(cv, cv + 200),
      contains('maxLength: kMaxSignedUrlLength'),
    );
    expect(src.indexOf("label: 'LinkedIn'"), lessThan(cv));
    final linkedin = src.indexOf("label: 'LinkedIn'");
    expect(
      src.substring(linkedin, linkedin + 200),
      isNot(contains('maxLength')),
    );
  });
}
