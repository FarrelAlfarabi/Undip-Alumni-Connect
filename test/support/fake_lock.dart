import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/policy_config.dart';
import 'package:undip_alumni_connect/lock/biometrics.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/lock/pin_hasher.dart';

/// A test clock you move by hand.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime(2026, 9, 30, 12);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

class FakeBiometrics implements BiometricProvider {
  FakeBiometrics({
    this.available = true,
    this.result = BiometricResult.success,
  });

  bool available;
  BiometricResult result;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricResult> authenticate(String reason) async {
    prompts++;
    return result;
  }
}

const testEmail = 'ahmad.ramadhan@example.com';
const testPin = '482913';

/// By default this person has already accepted the current privacy policy.
Map<String, dynamic> testProfile({
  String status = 'verified',
  String? policyVersion = kPolicyVersion,
}) => {
  'id': 'p1',
  'name': 'Ahmad Ramadhan',
  'email': testEmail,
  'verification_status': status,
  'policy_version': policyVersion,
};

/// A service on an in-memory store with a fast hasher and a fake clock.
LockService makeLock({
  MemoryLockStore? store,
  FakeBiometrics? bio,
  FakeClock? clock,
  bool enabled = true,
}) {
  return LockService(
    store: store ?? MemoryLockStore(),
    biometrics: bio ?? FakeBiometrics(available: false),
    hasher: PinHasher(iterations: 50, direct: true),
    clock: clock?.call,
    enabled: enabled,
  );
}

/// A service that already remembers [testProfile] and has [testPin] set.
Future<LockService> makeRememberedLock({
  MemoryLockStore? store,
  FakeBiometrics? bio,
  FakeClock? clock,
  bool withPin = true,
}) async {
  final lock = makeLock(store: store, bio: bio, clock: clock);
  await lock.remember(
    profileId: 'p1',
    displayName: 'Ahmad Ramadhan',
    email: testEmail,
  );
  if (withPin) await lock.setPin(testPin);
  return lock;
}

/// Taps the PIN pad keys for [pin], then lets async work finish.
Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    final key = find.byKey(Key('pin-$d'));
    await tester.ensureVisible(key); // small screens scroll
    await tester.tap(key);
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}
