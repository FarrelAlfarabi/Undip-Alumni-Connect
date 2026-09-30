import 'package:flutter/foundation.dart';

import 'biometrics.dart';
import 'lock_config.dart';
import 'lock_store.dart';
import 'masking.dart';
import 'pin_hasher.dart';

/// True only in a web preview build (see [LockService.shared]).
const bool kWebLockTest = bool.fromEnvironment('WEB_LOCK_TEST');

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

/// The 5th wrong PIN: local unlock data was wiped.
class PinLockedOut extends PinCheck {
  const PinLockedOut();
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
  }) : _hasher = hasher ?? PinHasher(),
       _now = clock ?? DateTime.now;

  /// The real service the app uses. On web it is disabled (see README),
  /// except in a PREVIEW build made with `--dart-define=WEB_LOCK_TEST=true`
  /// (scripts/vercel-build.sh does that for Vercel previews only) so the lock
  /// flow can be tried in a browser. Web storage is not real secure storage:
  /// this is for testing the flow, never for production.
  static LockService? _shared;
  static LockService get shared => _shared ??= (kIsWeb && !kWebLockTest)
      ? LockService(
          store: MemoryLockStore(),
          biometrics: const NoBiometrics(),
          enabled: false,
        )
      : LockService(
          store: const SecureLockStore(),
          biometrics: kIsWeb ? const NoBiometrics() : LocalAuthBiometrics(),
        );

  @visibleForTesting
  static set shared(LockService s) => _shared = s;

  final LockStore _store;
  final BiometricProvider _biometrics;
  final PinHasher _hasher;
  final DateTime Function() _now;

  /// False on web: nothing is remembered and no lock is ever shown.
  final bool enabled;

  /// True while a verified person is inside the app (HomeShell showing).
  /// The relock-after-background overlay only acts when this is true.
  bool sessionActive = false;

  static const _kId = 'lingkaran.lock.v1.profile_id';
  static const _kName = 'lingkaran.lock.v1.display_name';
  static const _kMasked = 'lingkaran.lock.v1.masked_email';
  static const _kPin = 'lingkaran.lock.v1.pin_hash';
  static const _kFailed = 'lingkaran.lock.v1.failed';
  static const _kWait = 'lingkaran.lock.v1.wait_until';
  static const _kBio = 'lingkaran.lock.v1.bio';

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
  /// masked email are stored. If this is a different person than before,
  /// the old PIN and biometric choice are dropped.
  Future<void> remember({
    required String profileId,
    required String displayName,
    required String email,
  }) async {
    if (!enabled) return;
    final previous = await _store.read(_kId);
    if (previous != null && previous != profileId) {
      await _clearSecrets();
    }
    await _store.write(_kId, profileId);
    await _store.write(_kName, displayName);
    await _store.write(_kMasked, maskEmail(email));
  }

  Future<bool> hasPin() async => (await _store.read(_kPin)) != null;

  Future<bool> biometricsAvailable() => _biometrics.isAvailable();

  Future<bool> biometricsEnabled() async =>
      (await _store.read(_kBio)) == '1' && await _biometrics.isAvailable();

  /// Sets (or replaces) the PIN. Stores a salted hash only.
  Future<void> setPin(String pin) async {
    assert(RegExp(r'^\d{6}$').hasMatch(pin));
    await _store.write(_kPin, await _hasher.hash(pin));
    await _store.delete(_kFailed);
    await _store.delete(_kWait);
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

  /// Checks a PIN. Wrong tries are counted and persisted (so restarting the
  /// app does not reset them). The 5th wrong PIN wipes all local unlock data.
  Future<PinCheck> checkPin(String pin) async {
    final stored = await _store.read(_kPin);
    if (stored == null) return const PinLockedOut();

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
    await _store.delete(_kPin);
    await _store.delete(_kFailed);
    await _store.delete(_kWait);
    await _store.delete(_kBio);
  }

  /// Wipes everything remembered on this device (used by "Switch account",
  /// "Forgot PIN", sign out, 5 wrong PINs, and a failed profile fetch). It
  /// never touches the server.
  Future<void> clear() async {
    sessionActive = false;
    await _clearSecrets();
    await _store.delete(_kId);
    await _store.delete(_kName);
    await _store.delete(_kMasked);
    _changes.value++;
  }
}
