/// The last list a screen loaded, kept in memory for this session only.
///
/// A tab that is opened again after its refresh window shows what it had
/// right away and refetches behind it, instead of a blank spinner. Nothing is
/// written to the device. Keys carry the profile id, and the cache is emptied
/// when the shell closes (Keluar, Ganti akun) and when the people I blocked
/// change, so another person or a blocked member is never shown from here.
class StaleCache {
  StaleCache._();

  static final Map<String, Object?> _items = {};

  /// What was last saved under [key], or null when nothing was or it is not a
  /// [T].
  static T? peek<T>(String key) {
    final v = _items[key];
    return v is T ? v : null;
  }

  /// Waits for [load], keeps its result under [key], and returns it. A failure
  /// leaves the old value alone and is passed on.
  static Future<T> remember<T>(String key, Future<T> load) async {
    final v = await load;
    _items[key] = v;
    return v;
  }

  static void clear() => _items.clear();
}
