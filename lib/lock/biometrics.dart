import 'package:local_auth/local_auth.dart';

/// Result of asking the device for a fingerprint check.
enum BiometricResult { success, failed, cancelled, unavailable }

abstract class BiometricProvider {
  /// True when the device has a fingerprint enrolled and usable.
  Future<bool> isAvailable();

  Future<BiometricResult> authenticate(String reason);
}

/// Real provider (Android BiometricPrompt, iOS Touch ID). Fingerprint only:
/// a device is treated as supported only if it reports a fingerprint
/// sensor, so a Face ID iPhone or a face-only Android never sees the option.
/// The OS prompt itself can't be limited to one sensor, so a phone with both
/// fingerprint and face enrolled may accept either one.
class LocalAuthBiometrics implements BiometricProvider {
  LocalAuthBiometrics([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).contains(
        BiometricType.fingerprint,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly:
            true, // never the device PIN: our own PIN is the fallback
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled => BiometricResult.cancelled,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.biometricLockout ||
        LocalAuthExceptionCode.temporaryLockout => BiometricResult.unavailable,
        _ => BiometricResult.failed,
      };
    } catch (_) {
      return BiometricResult.failed;
    }
  }
}

/// For web and tests: biometrics are never available.
class NoBiometrics implements BiometricProvider {
  const NoBiometrics();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<BiometricResult> authenticate(String reason) async =>
      BiometricResult.unavailable;
}
