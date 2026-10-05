import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/util/error_report.dart';

void main() {
  group('cleanErrorText', () {
    test('removes an email address', () {
      final t = cleanErrorText(
        'PostgrestException(message: duplicate key, details: Key (email)=(budi.santoso@example.com) already exists.)',
      );
      expect(t, isNot(contains('budi')));
      expect(t, isNot(contains('@')));
      expect(t, contains('[email]'));
      expect(t, contains('duplicate key'));
    });

    test('removes keys and tokens (JWT, sb_ keys, bearer, long random strings)', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIn0.sig_ABCdef123456';
      for (final raw in [
        'AuthException: invalid apikey $jwt',
        'Bad key sb_publishable_abc123DEF456ghi789',
        'Bad key sb_secret_abc123DEF456ghi789',
        'Header Authorization: Bearer abcdef1234567890abcdef',
        'token=9f8e7d6c5b4a39281706f5e4d3c2b1a0ffeeddcc',
      ]) {
        final t = cleanErrorText(raw);
        expect(t, isNot(contains('eyJ')), reason: raw);
        expect(t, isNot(contains('sb_publishable')), reason: raw);
        expect(t, isNot(contains('sb_secret')), reason: raw);
        expect(t, isNot(contains('abcdef1234567890')), reason: raw);
        expect(t, isNot(contains('9f8e7d6c')), reason: raw);
        expect(t, contains('[key]'), reason: raw);
      }
    });

    test('removes phone numbers and NIM style long numbers', () {
      final t = cleanErrorText(
        'Invalid phone +62 812-3456-7890 and 0812 3456 7890 for NIM 12010120130001, code 404',
      );
      expect(RegExp(r'\d{5,}').hasMatch(t), isFalse, reason: t);
      expect(t, isNot(contains('812-3456')));
      expect(t, contains('404')); // short numbers are kept
      expect(t, contains('[number]'));
    });

    test('removes URLs, including ones with a query string', () {
      final t = cleanErrorText(
        'ClientException: Failed host lookup, uri=https://xyz.supabase.co/rest/v1/job_posts?select=*&apikey=abc123 and http://a.example/path',
      );
      expect(t, isNot(contains('http')));
      expect(t, isNot(contains('supabase.co')));
      expect(t, isNot(contains('apikey=')));
      expect(t, contains('[link]'));
    });

    test('drops stack traces and keeps only the summary', () {
      final t = cleanErrorText(
        'Exception: boom\n#0      main (package:undip_alumni_connect/main.dart:10:3)\n#1      _rootRun (dart:async/zone.dart:1399:13)\n   at foo (file.dart:1)',
      );
      expect(t, 'Exception: boom');
    });

    test('removes ids (UUIDs)', () {
      final t = cleanErrorText(
        'Row 3f2504e0-4f89-11d3-9a0c-0305e82c3301 not found',
      );
      expect(t, isNot(contains('3f2504e0')));
      expect(t, contains('[id]'));
    });

    test('short summary: at most 300 characters', () {
      final t = cleanErrorText('x' * 5000);
      expect(t.length, lessThanOrEqualTo(300));
      expect(cleanErrorText('word ' * 200).length, lessThanOrEqualTo(300));
    });

    test('null, empty and plain text', () {
      expect(cleanErrorText(null), '');
      expect(cleanErrorText('   '), '');
      expect(cleanErrorText('Something broke'), 'Something broke');
    });

    test('one realistic mixed sample has nothing sensitive left', () {
      final t = cleanErrorText(
        'PostgrestException(message: new row violates policy for ahmad.ramadhan@example.com phone 081234567890 '
        'url https://x.supabase.co/rest/v1/a?apikey=sb_publishable_zzzzzzzzzzzzzzzzzzzz, code: 42501)\n#0 foo (package:a/b.dart:1)',
      );
      for (final bad in [
        'ahmad',
        '@',
        '0812',
        'supabase',
        'sb_publishable',
        'apikey',
        '#0',
      ]) {
        expect(t, isNot(contains(bad)), reason: '$bad in "$t"');
      }
      expect(t, contains('42501'));
    });
  });
}
