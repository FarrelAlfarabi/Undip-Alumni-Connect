import 'package:local_auth/local_auth.dart';

/// Result of asking the device for a fingerprint / face check.
enum BiometricResult { success, failed, cancelled, unavailable }

abstract class BiometricProvider {
  /// True when the device has biometrics enrolled and usable.
  Future<bool> isAvailable();

  Future<BiometricResult> authenticate(String reason);
}

/// Real provider (Android BiometricPrompt, iOS Face ID / Touch ID).
class LocalAuthBiometrics implements BiometricProvider {
  LocalAuthBiometrics([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
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
