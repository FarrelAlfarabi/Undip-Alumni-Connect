import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';
import 'package:undip_alumni_connect/util/friendly_error.dart';
import 'package:undip_alumni_connect/util/safe_url.dart';
import 'package:undip_alumni_connect/widgets/safe_link_chip.dart';

import '../support/fake_lock.dart';

/// Fixes for SA-13 (raw exception text) and SA-14 (unchecked links).
void main() {
  group('SA-13 friendly errors', () {
    test('network-looking errors get the network message', () {
      expect(friendlyError(TimeoutException('slow')), kNetworkError);
      expect(
        friendlyError(Exception('ClientException: Failed host lookup')),
        kNetworkError,
      );
      expect(
        friendlyError('SocketException: Connection refused'),
        kNetworkError,
      );
    });

    test('everything else gets the generic message, never the input', () {
      const leaky =
          'PostgrestException(message: JWT expired, url: https://x.supabase.co/rest/v1/a)';
      final msg = friendlyError(Exception(leaky));
      expect(msg, kGenericError);
      expect(msg.contains('supabase'), isFalse);
      expect(friendlyError(null), kGenericError);
    });

    test('load errors name the thing, not the error', () {
      final msg = friendlyLoadError(
        'the directory',
        Exception('secret-detail'),
      );
      expect(msg, contains('the directory'));
      expect(msg.contains('secret-detail'), isFalse);
    });

    testWidgets('verification never shows the exception text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VerificationScreen(
            lock: makeLock(),
            verifyEmail: (_) async => throw Exception(
              'ClientException: https://abcdefgh.supabase.co failed (JWT expired)',
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'someone@example.com');
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('supabase.co'), findsNothing);
      expect(find.textContaining('JWT'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining("Couldn't reach the server"), findsWidgets);
    });

    test('no screen interpolates a raw error into visible text', () {
      // Patterns that put an exception or snapshot error into a string.
      final bad = [
        RegExp(r'\$\{snapshot\.error\}'),
        RegExp(r'\$_loadError'),
        RegExp(r'Failed to send: \$e'),
        RegExp(r'Could not open conversation: \$e'),
        RegExp(r'=\s*e\.toString\(\)'),
        RegExp(r'Post failed: \$_error'),
        RegExp(r"'Failed: \$_error'"),
      ];
      final hits = <String>[];
      for (final f in Directory('lib/screens').listSync()) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (bad.any((r) => r.hasMatch(lines[i]))) {
            hits.add('${f.path}:${i + 1}');
          }
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });

  group('SA-14 safe links', () {
    test('accepts http and https', () {
      expect(
        parseHttpUrl('https://example.com/a?b=1')?.toString(),
        'https://example.com/a?b=1',
      );
      expect(parseHttpUrl('http://example.com')?.scheme, 'http');
      expect(parseHttpUrl('HTTPS://Example.com')?.scheme, 'https');
    });

    test('adds https to a bare host', () {
      expect(
        parseHttpUrl('linkedin.com/in/someone')?.toString(),
        'https://linkedin.com/in/someone',
      );
      expect(parseHttpUrl('  www.example.co.id  ')?.host, 'www.example.co.id');
    });

    test('refuses every other scheme', () {
      for (final bad in [
        'javascript:alert(1)',
        'JaVaScRiPt:alert(1)',
        'tel:+620000000000',
        'sms:+620000000000',
        'mailto:a@example.com',
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///etc/passwd',
        'data:text/html,<script>alert(1)</script>',
        'ftp://example.com/x',
        'whatsapp://send?text=hi',
        'market://details?id=x',
      ]) {
        expect(parseHttpUrl(bad), isNull, reason: bad);
      }
    });

    test('refuses malformed, credentialed and oversized links', () {
      for (final bad in [
        '',
        '   ',
        null,
        'https://',
        'https://user:pass@example.com',
        'https://exa mple.com',
        'not a link',
        'localhost',
        'https://${'a' * 600}.com',
      ]) {
        expect(parseHttpUrl(bad), isNull, reason: '$bad');
      }
    });

    test('validator: empty is fine unless required', () {
      expect(validateHttpUrl(''), isNull);
      expect(validateHttpUrl('  '), isNull);
      expect(validateHttpUrl('', required: true), isNotNull);
      expect(validateHttpUrl('javascript:alert(1)'), isNotNull);
      expect(validateHttpUrl('https://example.com'), isNull);
    });

    test('openHttpUrl never launches an unsafe link', () async {
      final launched = <Uri>[];
      Future<bool> fake(Uri u) async {
        launched.add(u);
        return true;
      }

      expect(await openHttpUrl('javascript:alert(1)', launcher: fake), isFalse);
      expect(await openHttpUrl('tel:123', launcher: fake), isFalse);
      expect(launched, isEmpty);
      expect(await openHttpUrl('example.com/x', launcher: fake), isTrue);
      expect(launched.single.toString(), 'https://example.com/x');
    });

    test('a failing launcher is a false, not a crash', () async {
      expect(
        await openHttpUrl(
          'https://example.com',
          launcher: (_) async => throw StateError('x'),
        ),
        isFalse,
      );
    });

    testWidgets('link chip: unsafe link shows a message and opens nothing', (
      tester,
    ) async {
      final launched = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeLinkChip(
              icon: Icons.link,
              label: 'LinkedIn',
              url: 'javascript:alert(1)',
              launcher: (u) async {
                launched.add(u);
                return true;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('LinkedIn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(launched, isEmpty);
      expect(find.textContaining("isn't valid"), findsOneWidget);
    });

    testWidgets('link chip: a good link opens', (tester) async {
      final launched = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeLinkChip(
              icon: Icons.link,
              label: 'Portfolio',
              url: 'https://example.com/me',
              launcher: (u) async {
                launched.add(u);
                return true;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Portfolio'));
      await tester.pump();
      expect(launched.single.toString(), 'https://example.com/me');
    });

    test('no screen opens a raw Uri.parse(...) link', () {
      final hits = <String>[];
      for (final f in Directory('lib/screens').listSync()) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('launchUrl(Uri.parse(')) {
            hits.add('${f.path}:${i + 1}');
          }
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    test('the apply form validates and normalises link fields', () {
      final text = File('lib/screens/apply_job_screen.dart').readAsStringSync();
      expect(text.contains('validateHttpUrl'), isTrue);
      expect(text.contains('parseHttpUrl'), isTrue);
    });
  });
}
