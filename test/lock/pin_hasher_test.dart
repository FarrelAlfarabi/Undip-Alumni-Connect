import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/masking.dart';
import 'package:undip_alumni_connect/lock/pin_hasher.dart';

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256 (published test vectors)', () {
    final salt = Uint8List.fromList(utf8.encode('salt'));
    final pw = utf8.encode('password');

    test('1 iteration', () {
      expect(
        hex(pbkdf2Sha256(pw, salt, 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });
    test('2 iterations', () {
      expect(
        hex(pbkdf2Sha256(pw, salt, 2)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });
    test('4096 iterations', () {
      expect(
        hex(pbkdf2Sha256(pw, salt, 4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });
  });

  group('PinHasher', () {
    final hasher = PinHasher(iterations: 200, direct: true);

    test('correct PIN verifies, wrong PIN does not', () async {
      final stored = await hasher.hash('482913');
      expect(await hasher.verify('482913', stored), isTrue);
      expect(await hasher.verify('482914', stored), isFalse);
      expect(await hasher.verify('', stored), isFalse);
    });

    test('stored value never contains the PIN and is salted', () async {
      final a = await hasher.hash('482913');
      final b = await hasher.hash('482913');
      expect(a.contains('482913'), isFalse);
      expect(a, isNot(b)); // different salt each time
      expect(a.startsWith(r'pbkdf2-sha256$200$'), isTrue);
    });

    test('malformed stored values are a non-match, not a crash', () async {
      for (final bad in [
        '',
        'garbage',
        r'pbkdf2-sha256$x$AAAA$AAAA',
        r'md5$1$AAAA$AAAA',
        r'pbkdf2-sha256$0$AAAA$AAAA',
        r'pbkdf2-sha256$10$!!!$!!!',
      ]) {
        expect(await hasher.verify('482913', bad), isFalse, reason: bad);
      }
    });

    test('uses the iteration count stored with the hash', () async {
      final old = await PinHasher(iterations: 100, direct: true).hash('111222');
      // A hasher configured with a different work factor still verifies it.
      expect(await hasher.verify('111222', old), isTrue);
    });
  });

  group('masking', () {
    test('shows first letter and domain only', () {
      expect(maskEmail('siti@example.com'), 's***@example.com');
      expect(maskEmail('ahmad.ramadhan@example.com'), 'a***@example.com');
    });

    test('never reveals the full local part', () {
      for (final e in ['ab@x.com', 'abc@x.com', 'a@x.com', 'long.name@x.id']) {
        final m = maskEmail(e);
        final local = e.substring(0, e.indexOf('@'));
        expect(m.contains(local) && local.length > 1, isFalse, reason: e);
        expect(m == e, isFalse);
      }
      expect(
        maskEmail('a@x.com'),
        '*'
        '***@x.com',
      );
    });

    test('unusable input gives ***', () {
      expect(maskEmail(''), '***');
      expect(maskEmail('no-at-sign'), '***');
      expect(maskEmail('@x.com'), '***');
      expect(maskEmail('a@'), '***');
    });

    test('initials', () {
      expect(initialsOf('Ahmad Ramadhan'), 'AR');
      expect(initialsOf('bunga'), 'B');
      expect(initialsOf('  '), '?');
      expect(initialsOf('a b c'), 'AB');
    });
  });
}
