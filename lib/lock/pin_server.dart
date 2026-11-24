import 'package:supabase_flutter/supabase_flutter.dart';

/// The account PIN in the database (20261124100000_account_pin.sql). One PIN
/// for the account, so a PIN made on the laptop opens the phone. The
/// database keeps a bcrypt hash and counts wrong tries for the account.
abstract class PinServer {
  /// Whether the signed in account has a PIN.
  Future<bool> hasPin();

  /// Sets or replaces the account PIN. Replacing needs [oldPin], or an email
  /// code sign in in the last 15 minutes; otherwise it fails with
  /// `old_pin_required`.
  Future<void> setPin(String pin, {String? oldPin});

  Future<ServerPinResult> check(String pin);

  Future<void> remove();
}

/// The account could not be reached (no internet, signed out, server error)
/// or refused. [reason] is a short code, never the PIN or the raw error.
class PinServerException implements Exception {
  const PinServerException(this.reason);
  final String reason;

  static const oldPinRequired = 'old_pin_required';
  static const notSignedIn = 'not_signed_in';
  @override
  String toString() => 'PinServerException($reason)';
}

sealed class ServerPinResult {
  const ServerPinResult();
}

class ServerPinOk extends ServerPinResult {
  const ServerPinOk();
}

class ServerPinWrong extends ServerPinResult {
  const ServerPinWrong(this.attemptsLeft, {this.waitUntil});
  final int attemptsLeft;
  final DateTime? waitUntil;
}

class ServerPinWait extends ServerPinResult {
  const ServerPinWait(this.until);
  final DateTime until;
}

/// The 5th wrong try: the account PIN was removed.
class ServerPinLocked extends ServerPinResult {
  const ServerPinLocked();
}

/// The account has no PIN.
class ServerPinNone extends ServerPinResult {
  const ServerPinNone();
}

/// Reads the answer of `pin_check`.
ServerPinResult parsePinCheck(Object? raw) {
  final m = raw is Map ? raw : const {};
  DateTime? time(Object? v) =>
      v == null ? null : DateTime.tryParse('$v')?.toLocal();
  switch (m['status']) {
    case 'ok':
      return const ServerPinOk();
    case 'wrong':
      return ServerPinWrong(
        (m['left'] as num?)?.toInt() ?? 0,
        waitUntil: time(m['wait_until']),
      );
    case 'wait':
      final t = time(m['wait_until']);
      if (t == null) throw const PinServerException('bad_answer');
      return ServerPinWait(t);
    case 'locked':
      return const ServerPinLocked();
    case 'none':
      return const ServerPinNone();
  }
  throw const PinServerException('bad_answer');
}

class SupabasePinServer implements PinServer {
  SupabasePinServer([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _c => _client ?? Supabase.instance.client;

  Future<T> _call<T>(Future<T> Function() f) async {
    if (_c.auth.currentSession == null) {
      throw const PinServerException('not_signed_in');
    }
    try {
      return await f();
    } on PinServerException {
      rethrow;
    } on PostgrestException catch (e) {
      // Only a short code: the raw text could echo the call.
      if (e.message.contains(PinServerException.oldPinRequired)) {
        throw const PinServerException(PinServerException.oldPinRequired);
      }
      if (e.code == '28000' ||
          e.message.contains(PinServerException.notSignedIn)) {
        throw const PinServerException(PinServerException.notSignedIn);
      }
      throw PinServerException('server_${e.code ?? 'error'}');
    } catch (_) {
      throw const PinServerException('network');
    }
  }

  @override
  Future<bool> hasPin() =>
      _call(() async => await _c.rpc('pin_status') == true);

  @override
  Future<void> setPin(String pin, {String? oldPin}) =>
      _call(() => _c.rpc('pin_set', params: {'p_pin': pin, 'p_old': ?oldPin}));

  @override
  Future<ServerPinResult> check(String pin) => _call(
    () async =>
        parsePinCheck(await _c.rpc('pin_check', params: {'p_pin': pin})),
  );

  @override
  Future<void> remove() => _call(() => _c.rpc('pin_remove'));
}
