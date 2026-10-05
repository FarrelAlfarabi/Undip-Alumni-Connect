import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App version, build number and device type. One place, used by the About
/// screen, the Welcome screen and feedback reports.
class AppInfo {
  const AppInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  /// "Lingkaran v0.9.0 (build 12) BETA".
  String get fullLabel => 'Lingkaran v$version (build $buildNumber) BETA';

  /// "v0.9.0 (build 12)".
  String get short => 'v$version (build $buildNumber)';

  static AppInfo? _shared;

  /// Replace in tests with a mocked value.
  @visibleForTesting
  static set shared(AppInfo? value) => _shared = value;

  /// Reads the real package info once. Falls back to "?" if it fails.
  static Future<AppInfo> load() async {
    final cached = _shared;
    if (cached != null) return cached;
    try {
      final p = await PackageInfo.fromPlatform();
      return _shared = AppInfo(version: p.version, buildNumber: p.buildNumber);
    } catch (_) {
      return const AppInfo(version: '?', buildNumber: '?');
    }
  }

  /// "android", "ios", "web", "windows" ...
  static String get platform =>
      kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
}
