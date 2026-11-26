import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/job_detail_screen.dart';
import 'package:undip_alumni_connect/util/app_language.dart';

Widget _app(Map<String, dynamic> job, String me) => MaterialApp(
  home: JobDetailScreen(
    job: job,
    currentUser: ValueNotifier({'id': me}),
    loadApplicantCount: () async => 3,
    loadHasApplied: () async => false,
  ),
);

void main() {
  // Tests show code text as written; here we want the real translation.
  setUp(() => AppLanguage.shared.passthrough = false);
  tearDown(() => AppLanguage.shared.passthrough = true);

  const job = {
    'id': 'j1',
    'title': 'Staf',
    'company': 'PT A',
    'industry': 'Retail',
    'description': 'Deskripsi',
    'contact_info': 'hrd@contoh.id',
    'posted_by': 'owner',
    'alumni_profiles': {'name': 'Dewi'},
  };

  testWidgets('owner sees own contact info and a translated count', (
    tester,
  ) async {
    await tester.pumpWidget(_app(job, 'owner'));
    await tester.pumpAndSettle();
    expect(find.text('hrd@contoh.id'), findsOneWidget);
    expect(find.text('3 lamaran diterima.'), findsOneWidget);
  });

  testWidgets('missing contact info is shown in Indonesian', (tester) async {
    await tester.pumpWidget(_app({...job, 'contact_info': null}, 'other'));
    await tester.pumpAndSettle();
    expect(find.text('Kontak tidak tersedia.'), findsOneWidget);
  });
}
