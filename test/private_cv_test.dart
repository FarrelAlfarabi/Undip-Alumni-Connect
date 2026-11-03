import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/util/cv_upload.dart';
import 'package:undip_alumni_connect/widgets/cv_link_chip.dart';

void main() {
  group('cvStoragePath', () {
    test('signed in: the first folder is the auth user id', () {
      expect(
        cvStoragePath(
          userId: 'u-1',
          jobId: 'j-9',
          safeName: 'cv.pdf',
          millis: 123,
        ),
        'u-1/j-9_123_cv.pdf',
      );
    });

    test('not signed in (old build): the old job folder path', () {
      expect(
        cvStoragePath(
          userId: null,
          jobId: 'j-9',
          safeName: 'cv.pdf',
          millis: 123,
        ),
        'j-9/123_cv.pdf',
      );
    });
  });

  group('CvLinkChip', () {
    testWidgets('asks for a signed link on tap, then opens it', (tester) async {
      final signed = <String>[];
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CvLinkChip(
              path: 'u-1/j-9_123_cv.pdf',
              signer: (p) async {
                signed.add(p);
                return 'https://x.supabase.co/storage/v1/object/sign/cvs/$p?token=t';
              },
              launcher: (u) async {
                opened.add(u);
                return true;
              },
            ),
          ),
        ),
      );
      // Nothing is requested while the screen is only shown.
      expect(signed, isEmpty);
      await tester.tap(find.text('CV'));
      await tester.pump();
      await tester.pump();
      expect(signed, ['u-1/j-9_123_cv.pdf']);
      expect(opened.single.queryParameters['token'], 't');
    });

    testWidgets('a failed signed link shows a calm message', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CvLinkChip(
              path: 'a/b.pdf',
              signer: (_) async => throw Exception('StorageException: secret'),
              launcher: (_) async {
                opened = true;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('CV'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opened, isFalse);
      expect(find.textContaining('CV'), findsWidgets);
      expect(find.textContaining('secret'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
