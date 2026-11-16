import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the lock data lives. Real app: platform secure storage
/// (Keychain on iOS, Keystore-backed on Android). Tests: memory.
abstract class LockStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureLockStore implements LockStore {
  const SecureLockStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Web: the browser's own local storage. The secure storage package encrypts
/// with a key kept next to the data and needs a secure page; when that key was
/// lost or unreadable the remembered person vanished and the next visit asked
/// for an email code again. The web PIN is a screen lock only (see
/// [LockService.shared]), so plain local storage loses nothing. It lives
/// until the person clears site data.
class WebLockStore implements LockStore {
  const WebLockStore();

  static const _prefix = 'lingkaran.web.';

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString('$_prefix$key');

  @override
  Future<void> write(String key, String value) async {
    await (await SharedPreferences.getInstance()).setString(
      '$_prefix$key',
      value,
    );
  }

  @override
  Future<void> delete(String key) async {
    await (await SharedPreferences.getInstance()).remove('$_prefix$key');
  }
}

class MemoryLockStore implements LockStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}
