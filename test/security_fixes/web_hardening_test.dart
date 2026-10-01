import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fixes for SA-12 (security headers) and SA-19 (build must refuse a
/// non-publishable Supabase key). These fail before the fix and pass after.
String jwt(Map<String, dynamic> payload) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc(payload)}.c2lnbmF0dXJl';
}

Future<ProcessResult> check(
  String key, {
  String url = 'https://abc.supabase.co',
}) {
  return Process.run(
    'bash',
    ['scripts/check_supabase_env.sh'],
    environment: {'SUPABASE_URL': url, 'SUPABASE_ANON_KEY': key},
  );
}

void main() {
  group('SA-12 security headers in vercel.json', () {
    late Map<String, String> headers;
    late Map<String, String> csp;

    setUpAll(() {
      final json = jsonDecode(File('vercel.json').readAsStringSync()) as Map;
      final rules = (json['headers'] as List?) ?? const [];
      expect(rules, isNotEmpty, reason: 'vercel.json needs a headers section');
      final rule = rules.cast<Map>().firstWhere(
        (r) => r['source'] == '/(.*)',
        orElse: () => throw StateError('no catch-all header rule'),
      );
      headers = {
        for (final h in (rule['headers'] as List).cast<Map>())
          (h['key'] as String): h['value'] as String,
      };
      csp = {
        for (final d in (headers['Content-Security-Policy'] ?? '').split(';'))
          if (d.trim().isNotEmpty)
            d.trim().split(' ').first: d
                .trim()
                .substring(d.trim().split(' ').first.length)
                .trim(),
      };
    });

    test('basic protective headers are present', () {
      expect(headers['X-Content-Type-Options'], 'nosniff');
      expect(headers['X-Frame-Options'], 'DENY');
      expect(headers['Referrer-Policy'], isNotEmpty);
      expect(headers['Permissions-Policy'], contains('camera=()'));
      expect(headers['Strict-Transport-Security'], contains('max-age='));
    });

    test('CSP blocks framing, plugins and base-tag tricks', () {
      expect(csp['frame-ancestors'], "'none'");
      expect(csp['object-src'], "'none'");
      expect(csp['base-uri'], "'self'");
      expect(csp['default-src'], "'self'");
    });

    test('CSP scripts: no unsafe-inline and no unsafe-eval', () {
      final script = csp['script-src'] ?? '';
      expect(script, contains("'self'"));
      expect(script, isNot(contains("'unsafe-inline'")));
      expect(
        script.replaceAll("'wasm-unsafe-eval'", ''),
        isNot(contains("'unsafe-eval'")),
      );
    });

    test('CSP only lets the app talk to Supabase and the CDNs it needs', () {
      final connect = csp['connect-src'] ?? '';
      expect(connect, contains('https://*.supabase.co'));
      expect(connect, isNot(contains(' *')));
      expect(connect, isNot(contains('http:')));
    });
  });

  group('SA-19 build refuses a non-publishable key', () {
    test('publishable key format is accepted', () async {
      final r = await check('sb_publishable_abcdefghijklmnop');
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });

    test('legacy anon JWT is accepted', () async {
      final r = await check(jwt({'role': 'anon', 'iss': 'supabase'}));
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });

    test('service-role JWT is refused and never printed', () async {
      final key = jwt({'role': 'service_role'});
      final r = await check(key);
      expect(r.exitCode, isNot(0));
      expect('${r.stdout}${r.stderr}', isNot(contains(key)));
      expect('${r.stdout}${r.stderr}', contains('service'));
    });

    test('secret-format key is refused', () async {
      final r = await check('sb_secret_abcdefghijklmnop');
      expect(r.exitCode, isNot(0));
    });

    test('empty, unknown-format and malformed keys are refused', () async {
      for (final k in ['', 'hello', 'a.b.c', 'eyJhbGciOiJIUzI1NiJ9.!!!.sig']) {
        final r = await check(k);
        expect(r.exitCode, isNot(0), reason: 'key "$k"');
      }
    });

    test('non-https Supabase URL is refused', () async {
      final r = await check(
        'sb_publishable_abcdefghijklmnop',
        url: 'http://abc.supabase.co',
      );
      expect(r.exitCode, isNot(0));
    });

    test('the Vercel build runs the check before writing .env', () {
      final text = File('scripts/vercel-build.sh').readAsStringSync();
      final check = text.indexOf('check_supabase_env.sh');
      final write = text.indexOf('cat > .env');
      expect(check, greaterThan(-1));
      expect(write, greaterThan(check));
    });
  });
}
