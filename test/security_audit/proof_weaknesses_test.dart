import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';

import '../support/fake_lock.dart';

/// SA-13: a failed verification shows the raw exception text to the user.
/// Supabase and network exceptions can contain the project URL, status codes
/// and internals. WEAKNESS PRESENT: the raw text is on screen.
void main() {
  testWidgets('SA-13 proof: raw exception text reaches the screen', (
    tester,
  ) async {
    const leaky =
        'ClientException: connection to https://abcdefgh.supabase.co failed (JWT expired)';
    await tester.pumpWidget(
      MaterialApp(
        home: VerificationScreen(
          lock: makeLock(),
          verifyEmail: (_) async => throw Exception(leaky),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'someone@example.com');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('supabase.co'), findsOneWidget);
  });

  /// SA-14: applicant-supplied links are opened without any scheme check.
  test('SA-14 proof: job_applicants_screen opens raw Uri.parse(url)', () {
    final text = File('lib/screens/job_applicants_screen.dart')
        .readAsStringSync();
    expect(text.contains('launchUrl(Uri.parse(url))'), isTrue);
  });
}
