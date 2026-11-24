import 'package:undip_alumni_connect/lock/pin_server.dart';

/// Stands in for the account PIN functions in the database
/// (20261124100000_account_pin.sql): one PIN per account, wrong tries counted
/// on the account, a short wait from the 3rd wrong try, and the 5th wrong try
/// removes the account PIN. Two LockServices sharing one fake are two devices.
class FakePinServer implements PinServer {
  FakePinServer({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  /// The account PIN (the real database keeps a bcrypt hash only).
  String? pin;
  int failed = 0;
  DateTime? waitUntil;

  /// True: every call fails like a phone without internet.
  bool offline = false;

  /// True: the person signed in with an email code in the last 15 minutes,
  /// so a PIN can be replaced without the old one.
  bool recentSignIn = true;
  final calls = <String>[];

  void _net(String name) {
    calls.add(name);
    if (offline) throw const PinServerException('offline');
  }

  @override
  Future<bool> hasPin() async {
    _net('pin_status');
    return pin != null;
  }

  @override
  Future<void> setPin(String newPin, {String? oldPin}) async {
    _net('pin_set');
    if (pin != null && oldPin != pin && !recentSignIn) {
      throw const PinServerException(PinServerException.oldPinRequired);
    }
    pin = newPin;
    failed = 0;
    waitUntil = null;
  }

  @override
  Future<void> remove() async {
    _net('pin_remove');
    pin = null;
    failed = 0;
    waitUntil = null;
  }

  @override
  Future<ServerPinResult> check(String tried) async {
    _net('pin_check');
    if (pin == null) return const ServerPinNone();
    final w = waitUntil;
    if (w != null && w.isAfter(_now())) return ServerPinWait(w);
    if (tried == pin) {
      failed = 0;
      waitUntil = null;
      return const ServerPinOk();
    }
    failed++;
    if (failed >= 5) {
      pin = null;
      failed = 0;
      waitUntil = null;
      return const ServerPinLocked();
    }
    DateTime? until;
    if (failed >= 3) {
      until = waitUntil = _now().add(const Duration(seconds: 10));
    }
    return ServerPinWrong(5 - failed, waitUntil: until);
  }
}
