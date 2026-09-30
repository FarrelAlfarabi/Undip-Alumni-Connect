import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'lock_config.dart';

/// Runs [fn] with [arg], possibly on another isolate. The default uses
/// Flutter's `compute` so a slow hash does not freeze the UI.
typedef ComputeRunner = Future<R> Function<A, R>(R Function(A) fn, A arg);

Future<R> _defaultRunner<A, R>(R Function(A) fn, A arg) => compute(fn, arg);
Future<R> _directRunner<A, R>(R Function(A) fn, A arg) async => fn(arg);

class _HashJob {
  const _HashJob(this.pin, this.salt, this.iterations);
  final String pin;
  final Uint8List salt;
  final int iterations;
}

Uint8List _pbkdf2(_HashJob job) =>
    pbkdf2Sha256(utf8.encode(job.pin), job.salt, job.iterations);

/// PBKDF2-HMAC-SHA256, one 32-byte block (dkLen = hLen), per RFC 8018.
/// Public so it can be checked against published test vectors.
@visibleForTesting
Uint8List pbkdf2Sha256(List<int> password, Uint8List salt, int iterations) {
  final hmac = Hmac(sha256, password);
  final block = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
  block[block.length - 1] = 1; // block index 1, big-endian
  var u = Uint8List.fromList(hmac.convert(block).bytes);
  final out = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = Uint8List.fromList(hmac.convert(u).bytes);
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return out;
}

/// Salted PIN hashing. The stored string looks like
/// `pbkdf2-sha256$60000$<salt b64>$<hash b64>`; the PIN itself is never
/// stored or logged.
class PinHasher {
  PinHasher({
    this.iterations = kPinHashIterations,
    Random? random,
    bool direct = false,
  }) : _random = random ?? Random.secure(),
       _run = direct ? _directRunner : _defaultRunner;

  final int iterations;
  final Random _random;
  final ComputeRunner _run;

  static const _scheme = 'pbkdf2-sha256';

  Future<String> hash(String pin) async {
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final digest = await _run(_pbkdf2, _HashJob(pin, salt, iterations));
    return '$_scheme\$$iterations\$${base64.encode(salt)}\$${base64.encode(digest)}';
  }

  /// True only when [pin] matches [stored]. A malformed [stored] is a
  /// non-match, never an exception.
  Future<bool> verify(String pin, String stored) async {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return false;
    final iter = int.tryParse(parts[1]);
    if (iter == null || iter < 1 || iter > 5000000) return false;
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      return false;
    }
    final actual = await _run(_pbkdf2, _HashJob(pin, salt, iter));
    return _constantTimeEquals(actual, expected);
  }
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
