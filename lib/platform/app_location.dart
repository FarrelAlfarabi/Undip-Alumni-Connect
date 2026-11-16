import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// The main places of the app shell. Each has its own web address.
enum ShellPlace { home, members, explore, chat, profile }

/// Web addresses for the app shell, so a refresh or a shared link opens the
/// same tab. Phones ignore all of this: [report] does nothing there.
///
/// Paths: `/` Home, `/members`, `/explore` (Marketplace),
/// `/explore/businesses`, `/explore/jobs`, `/chat`, `/profile`.
class AppLocation {
  AppLocation._();

  /// The path the browser opened with, read once in `main`. The first shell
  /// takes it ([takeInitial]); later shells (after Ganti akun) start on Home.
  static String? initialPath;

  /// Sends a path to the browser address bar. Tests replace it.
  static void Function(String path) reporter = _toBrowser;

  static String? _last;

  static void _toBrowser(String path) {
    if (!kIsWeb) return;
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(path),
      replace: true,
    );
  }

  static void reset() {
    reporter = _toBrowser;
    initialPath = null;
    _last = null;
  }

  static const _segments = ['', 'businesses', 'jobs'];

  static String pathFor(ShellPlace place, {int segment = 0}) => switch (place) {
    ShellPlace.home => '/',
    ShellPlace.members => '/members',
    ShellPlace.explore =>
      segment > 0 && segment < _segments.length
          ? '/explore/${_segments[segment]}'
          : '/explore',
    ShellPlace.chat => '/chat',
    ShellPlace.profile => '/profile',
  };

  /// Reads a path back into a place and an Explore segment. Anything not
  /// known opens Home.
  static (ShellPlace, int) parse(String path) {
    final parts = Uri.parse(path.isEmpty ? '/' : path).pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return (ShellPlace.home, 0);
    switch (parts.first) {
      case 'members':
        return (ShellPlace.members, 0);
      case 'explore':
        final i = parts.length > 1 ? _segments.indexOf(parts[1]) : 0;
        return (ShellPlace.explore, i < 0 ? 0 : i);
      case 'chat':
        return (ShellPlace.chat, 0);
      case 'profile':
        return (ShellPlace.profile, 0);
      default:
        return (ShellPlace.home, 0);
    }
  }

  /// The start path, given out once.
  static (ShellPlace, int) takeInitial() {
    final p = initialPath;
    initialPath = null;
    return parse(p ?? '/');
  }

  /// Reports [path] unless it is already showing.
  static void report(String path) {
    if (path == _last) return;
    _last = path;
    reporter(path);
  }
}
