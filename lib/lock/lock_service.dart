import 'package:flutter/foundation.dart';

import '../auth/login_api.dart' show kRealLogin;
import 'biometrics.dart';
import 'lock_config.dart';
import 'lock_store.dart';
import 'masking.dart';
import 'pin_hasher.dart';
import 'pin_server.dart';

/// What we remember about the verified person on this device. Deliberately
/// small: an id, a display name and a masked email hint. Never the full
/// profile and never the full email.
class RememberedUser {
  const RememberedUser({
    required this.profileId,
    required this.displayName,
    required this.maskedEmail,
  });

  final String profileId;
  final String displayName;
  final String maskedEmail;
}

sealed class PinCheck {
  const PinCheck();
}

class PinOk extends PinCheck {
  const PinOk();
}

class PinWrong extends PinCheck {
  const PinWrong(this.attemptsLeft, {this.waitUntil});

  final int attemptsLeft;

  /// Set when this wrong try starts a cool-down.
  final DateTime? waitUntil;
}

/// Too soon after a wrong try. The attempt was NOT counted.
class PinWait extends PinCheck {
  const PinWait(this.until);
  final DateTime until;
}

/// The 5th wrong PIN: local unlock data was wiped. [resetElsewhere]: the
/// account PIN was removed on another device (5 wrong tries there, or "Hapus
/// PIN"), so this device must sign in again too.
class PinLockedOut extends PinCheck {
  const PinLockedOut({this.resetElsewhere = false});
  final bool resetElsewhere;
}

/// The PIN this device had before one PIN per account (24 Nov 2026). The
/// account already has another PIN, made on another device: use that one.
class PinOldDevicePin extends PinCheck {
  const PinOldDevicePin();
}

/// The account PIN is not on this device yet and the account cannot be
/// reached. Nothing was counted.
class PinOffline extends PinCheck {
  const PinOffline();
}

/// Saving the PIN to the account failed. Nothing was saved anywhere.
class PinSyncException implements Exception {
  const PinSyncException(this.cause);
  final Object cause;

  /// The account has a PIN and this sign in may not replace it without the
  /// old one (use "Lupa PIN" to sign in again with an email code).
  bool get needsOldPin =>
      cause is PinServerException &&
      (cause as PinServerException).reason == PinServerException.oldPinRequired;
  @override
  String toString() => 'PinSyncException($cause)';
}

/// Device-level convenience lock. NOT real security: verification is an
/// email match with no real auth, so anyone who knows a valid alumni email
/// can still verify as that person. This only saves the owner from
/// re-verifying on each launch and keeps casual bystanders out of an
/// unlocked phone.
class LockService {
  LockService({
    required this._store,
    required this._biometrics,
    PinHasher? hasher,
    DateTime Function()? clock,
    this.enabled = true,
    this._server,
  }) : _hasher = hasher ?? PinHasher(),
       _now = clock ?? DateTime.now;

  /// The real service the app uses. The PIN lock is on for web too (decided
  /// 30 Oct 2026). On web it is a screen lock only: a browser has no secure
  /// storage, so it does not stop someone who can open the developer tools.
  /// There are no biometrics on web.
  static LockService? _shared;
  static LockService get shared =>
      _shared ??= LockService.forPlatform(web: kIsWeb);

  /// With the real login the PIN belongs to the account (one PIN on every
  /// device); without it (demo builds) it stays on the device only.
  factory LockService.forPlatform({required bool web}) => LockService(
    store: web ? const WebLockStore() : const SecureLockStore(),
    biometrics: web ? const NoBiometrics() : LocalAuthBiometrics(),
    server: kRealLogin ? SupabasePinServer() : null,
  );

  @visibleForTesting
  static set shared(LockService s) => _shared = s;

  final LockStore _store;
  final BiometricProvider _biometrics;
  final PinHasher _hasher;
  final DateTime Function() _now;

  /// The account PIN. Null: the PIN is kept on this device only.
  final PinServer? _server;

  /// The PIN last typed correctly, kept in memory only (never stored) for a
  /// few minutes, so "Ubah PIN" can prove the old PIN to the account.
  String? _lastGoodPin;
  DateTime? _lastGoodAt;

  void _rememberGood(String pin) {
    _lastGoodPin = pin;
    _lastGoodAt = _now();
  }

  String? get _recentGoodPin {
    final at = _lastGoodAt;
    if (at == null || _now().difference(at) > const Duration(minutes: 5)) {
      return null;
    }
    return _lastGoodPin;
  }

  void _forgetGood() {
    _lastGoodPin = null;
    _lastGoodAt = null;
  }

  /// False only for a service built for tests or a platform without a lock.
  final bool enabled;

  /// True while a verified person is inside the app (HomeShell showing).
  /// The relock-after-background overlay only acts when this is true.
  bool sessionActive = false;

  static const _kId = 'lingkaran.lock.v1.profile_id';
  static const _kName = 'lingkaran.lock.v1.display_name';
  static const _kMasked = 'lingkaran.lock.v1.masked_email';
  static const _kPin = 'lingkaran.lock.v1.pin_hash';
  // Which profile the PIN belongs to. Lets the PIN survive a sign out, while
  // a different person verifying on the same phone never inherits it.
  static const _kOwner = 'lingkaran.lock.v1.owner_id';
  static const _kFailed = 'lingkaran.lock.v1.failed';
  static const _kWait = 'lingkaran.lock.v1.wait_until';
  static const _kBio = 'lingkaran.lock.v1.bio';
  // '1': the account has a PIN (learned from the server), even when this
  // device has no copy of it yet.
  static const _kAccount = 'lingkaran.lock.v1.account_pin';
  // '1': the local hash is a copy of the account PIN, not a PIN made on this
  // device before one PIN per account.
  static const _kSynced = 'lingkaran.lock.v1.pin_synced';
  static const _kIntroPrefix = 'lingkaran.intro.v1.seen.';
  // Web only: "someone signed in on this browser before", with a first name.
  // It only picks which start screen shows. It never grants entry.
  static const _kReturning = 'lingkaran.returning.v1.first_name';

  final ValueNotifier<int> _changes = ValueNotifier(0);
  ValueListenable<int> get changes => _changes;

  /// Reads what is remembered, or null if nothing (or if disabled).
  Future<RememberedUser?> load() async {
    if (!enabled) return null;
    final id = await _store.read(_kId);
    if (id == null || id.isEmpty) return null;
    return RememberedUser(
      profileId: id,
      displayName: await _store.read(_kName) ?? 'there',
      maskedEmail: await _store.read(_kMasked) ?? '',
    );
  }

  /// Remember a freshly verified person. Only the id, a display name and a
  /// masked email are stored. The PIN and biometric choice are kept only if
  /// they belong to this same person. If they belong to someone else, or to
  /// nobody we can name, they are dropped, so the new person is offered PIN
  /// setup and never inherits another person's PIN.
  Future<void> remember({
    required String profileId,
    required String displayName,
    required String email,
  }) async {
    if (!enabled) return;
    if (await _store.read(_kPin) != null ||
        await _store.read(_kAccount) != null) {
      var owner = await _store.read(_kOwner);
      if (owner == null || owner.isEmpty) {
        // Saved before owners were recorded: the remembered person owns it.
        final previous = await _store.read(_kId);
        owner = (previous == null || previous.isEmpty) ? null : previous;
      }
      if (owner == profileId) {
        await _store.write(_kOwner, profileId);
      } else {
        await _clearSecrets();
      }
    }
    await _store.write(_kId, profileId);
    await _store.write(_kName, displayName);
    await _store.write(_kMasked, maskEmail(email));
    await _store.delete(_kReturning);
  }

  /// Web: the first name of the person whose sign in expired on this
  /// browser, or null. Used only to show "welcome back" instead of the
  /// first-time Welcome; the person still signs in with an email code.
  Future<String?> returningName() async {
    final n = await _store.read(_kReturning);
    return (n == null || n.isEmpty) ? null : n;
  }

  /// Keeps the first name only (no email, no id, no full name).
  Future<void> markReturning(String displayName) async {
    final n = displayName.trim();
    if (n.isEmpty) return;
    await _store.write(_kReturning, n.split(RegExp(r'\s+')).first);
  }

  Future<void> clearReturning() => _store.delete(_kReturning);

  /// Whether this person has already been through the feature intro on this
  /// device. Kept per profile id so a shared phone shows it to each person.
  Future<bool> introSeen(String profileId) async =>
      (await _store.read('$_kIntroPrefix$profileId')) == '1';

  Future<void> markIntroSeen(String profileId) =>
      _store.write('$_kIntroPrefix$profileId', '1');

  /// True when this device has a PIN or the account has one.
  Future<bool> hasPin() async =>
      (await _store.read(_kPin)) != null ||
      (await _store.read(_kAccount)) == '1';

  /// After a sign in (or on opening the app with a stored sign in): learn
  /// whether the account has a PIN, so a PIN made on another device is asked
  /// for here and no second PIN is made. Without internet nothing changes.
  ///
  /// Returns true when this device had the account PIN but the account no
  /// longer has one (5 wrong tries or "Hapus PIN" on another device). The
  /// PIN here is dropped; on opening the app the caller must ask for a new
  /// email code sign in, so the lock is not simply gone.
  Future<bool> syncFromAccount() async {
    final server = _server;
    if (!enabled || server == null) return false;
    final id = await _store.read(_kId);
    if (id == null || id.isEmpty) return false;
    final bool has;
    try {
      has = await server.hasPin();
    } catch (_) {
      return false;
    }
    var reset = false;
    if (has) {
      await _store.write(_kAccount, '1');
      await _store.write(_kOwner, id);
    } else if (await _store.read(_kSynced) == '1' ||
        await _store.read(_kAccount) == '1') {
      await _clearSecrets();
      reset = true;
    }
    _changes.value++;
    return reset;
  }

  Future<bool> biometricsAvailable() => _biometrics.isAvailable();

  Future<bool> biometricsEnabled() async =>
      (await _store.read(_kBio)) == '1' && await _biometrics.isAvailable();

  /// Sets (or replaces) the PIN. With an account PIN it is saved to the
  /// account first; if that fails nothing is saved anywhere and
  /// [PinSyncException] is thrown, so the devices never disagree. This
  /// device keeps a salted hash only.
  Future<void> setPin(String pin) async {
    assert(RegExp(r'^\d{6}$').hasMatch(pin));
    final server = _server;
    if (server != null) {
      try {
        await server.setPin(pin, oldPin: _recentGoodPin);
      } on PinServerException catch (e) {
        throw PinSyncException(e);
      }
    }
    await _saveLocal(pin, synced: server != null);
    _rememberGood(pin);
    _changes.value++;
  }

  Future<void> _saveLocal(String pin, {required bool synced}) async {
    final owner = await _store.read(_kId);
    if (owner != null && owner.isNotEmpty) await _store.write(_kOwner, owner);
    await _store.write(_kPin, await _hasher.hash(pin));
    if (synced) {
      await _store.write(_kSynced, '1');
      await _store.write(_kAccount, '1');
    } else {
      await _store.delete(_kSynced);
    }
    await _store.delete(_kFailed);
    await _store.delete(_kWait);
  }

  /// Removes the PIN (and the fingerprint choice, which needs a PIN to fall
  /// back on), from the account too. The remembered person stays, so the app
  /// keeps opening without a PIN until a new one is set. If the account
  /// cannot be reached nothing is removed and [PinSyncException] is thrown.
  Future<void> removePin() async {
    final server = _server;
    if (server != null) {
      try {
        await server.remove();
      } on PinServerException catch (e) {
        throw PinSyncException(e);
      }
    }
    await _clearSecrets();
    _changes.value++;
  }

  Future<void> setBiometricsEnabled(bool on) async {
    if (on) {
      await _store.write(_kBio, '1');
    } else {
      await _store.delete(_kBio);
    }
    _changes.value++;
  }

  Future<BiometricResult> authenticateBiometric(String reason) =>
      _biometrics.authenticate(reason);

  /// How many wrong tries are left before the wipe.
  Future<int> attemptsLeft() async =>
      kMaxPinAttempts - (int.tryParse(await _store.read(_kFailed) ?? '') ?? 0);

  Future<DateTime?> waitUntil() async {
    final ms = int.tryParse(await _store.read(_kWait) ?? '');
    if (ms == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    return until.isAfter(_now()) ? until : null;
  }

  /// Checks a PIN. With an account PIN the database checks it and counts
  /// wrong tries for the account (every device); this device only falls back
  /// to its cached copy when the account cannot be reached. Without one,
  /// wrong tries are counted here. The 5th wrong PIN wipes all local unlock
  /// data.
  Future<PinCheck> checkPin(String pin) async {
    final stored = await _store.read(_kPin);
    final account = await _store.read(_kAccount) == '1';
    if (stored == null && !account) return const PinLockedOut();
    final server = _server;
    if (server == null) return _checkLocal(pin, stored!);

    final ServerPinResult answer;
    try {
      answer = await server.check(pin);
    } on PinServerException {
      // No internet: the copy of the PIN last used here still works.
      if (stored == null) return const PinOffline();
      return _checkLocal(pin, stored);
    }
    final synced = await _store.read(_kSynced) == '1';
    switch (answer) {
      case ServerPinOk():
        await _saveLocal(pin, synced: true);
        _rememberGood(pin);
        return const PinOk();
      case ServerPinWrong(:final attemptsLeft, :final waitUntil):
        if (stored != null && !synced && await _hasher.verify(pin, stored)) {
          // Said once: the old device PIN is dropped, so from now on only
          // the account PIN counts here.
          await _store.delete(_kPin);
          await _store.write(_kAccount, '1');
          return const PinOldDevicePin();
        }
        return PinWrong(attemptsLeft, waitUntil: waitUntil);
      case ServerPinWait(:final until):
        return PinWait(until);
      case ServerPinLocked():
        await clear();
        return const PinLockedOut();
      case ServerPinNone():
        if (stored == null || synced || account) {
          // The account PIN was removed on another device.
          await clear();
          return const PinLockedOut(resetElsewhere: true);
        }
        // A PIN made here before one PIN per account: check it here, then
        // give it to the account so the other devices can use it.
        final local = await _checkLocal(pin, stored);
        if (local is PinOk) {
          _rememberGood(pin);
          try {
            await server.setPin(pin);
            await _saveLocal(pin, synced: true);
          } on PinServerException {
            // Moved next time.
          }
        }
        return local;
    }
  }

  Future<PinCheck> _checkLocal(String pin, String stored) async {
    final wait = await waitUntil();
    if (wait != null) return PinWait(wait);

    if (await _hasher.verify(pin, stored)) {
      await _store.delete(_kFailed);
      await _store.delete(_kWait);
      return const PinOk();
    }

    final failed = (int.tryParse(await _store.read(_kFailed) ?? '') ?? 0) + 1;
    if (failed >= kMaxPinAttempts) {
      await clear();
      return const PinLockedOut();
    }
    await _store.write(_kFailed, '$failed');
    DateTime? until;
    if (failed >= kDelayAfterAttempts) {
      until = _now().add(kWrongPinDelay);
      await _store.write(_kWait, '${until.millisecondsSinceEpoch}');
    }
    return PinWrong(kMaxPinAttempts - failed, waitUntil: until);
  }

  Future<void> _clearSecrets() async {
    await _store.delete(_kAccount);
    await _store.delete(_kSynced);
    await _store.delete(_kPin);
    await _store.delete(_kOwner);
    await _store.delete(_kFailed);
    await _store.delete(_kWait);
    await _store.delete(_kBio);
  }

  /// Sign out: forget who is signed in, but keep the PIN (and fingerprint
  /// choice) with its owner, so verifying the same person again skips PIN
  /// setup. It never touches the server.
  Future<void> signOut() async {
    sessionActive = false;
    _forgetGood();
    await _store.delete(_kId);
    await _store.delete(_kName);
    await _store.delete(_kMasked);
    await _store.delete(_kReturning);
    _changes.value++;
  }

  /// Wipes everything remembered on this device (used by "Switch account",
  /// "Forgot PIN", 5 wrong PINs, a profile that no longer exists, and
  /// account deletion). It never touches the server.
  Future<void> clear() async {
    sessionActive = false;
    _forgetGood();
    await _clearSecrets();
    await _store.delete(_kId);
    await _store.delete(_kName);
    await _store.delete(_kMasked);
    await _store.delete(_kReturning);
    _changes.value++;
  }
}
