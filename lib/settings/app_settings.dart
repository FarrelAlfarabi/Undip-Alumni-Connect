import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide, per-device preferences. Plain choices only (nothing secret):
/// anything sensitive, like the PIN, lives in the lock service instead.
///
/// Today that is the theme. Add new preferences here so Settings and the app
/// root both read from one place.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._themeMode);

  /// Used by tests and as a fallback when storage can't be read: defaults
  /// only, nothing is saved.
  AppSettings.inMemory([ThemeMode themeMode = ThemeMode.system])
    : _prefs = null,
      _themeMode = themeMode;

  static const themeKey = 'lingkaran.settings.v1.theme_mode';

  /// The instance the real app uses. Set once in `main()`.
  static AppSettings shared = AppSettings.inMemory();

  final SharedPreferences? _prefs;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  /// Loads saved preferences. Never throws: unreadable storage means the
  /// defaults (follow the system theme).
  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettings._(prefs, _parseTheme(prefs.getString(themeKey)));
    } catch (_) {
      return AppSettings.inMemory();
    }
  }

  static ThemeMode _parseTheme(String? name) {
    for (final m in ThemeMode.values) {
      if (m.name == name) return m;
    }
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      await _prefs?.setString(themeKey, mode.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}
