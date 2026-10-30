import 'dart:async';

import '../config/policy_config.dart';

/// What we show when something fails. Never include the exception text:
/// Supabase and network errors can carry the project URL, status codes and
/// database internals.
const String kGenericError = 'Something went wrong. Please try again.';
const String kNetworkError =
    "Couldn't reach the server. Check your connection and try again.";

/// Shown when sign-in is refused because an admin suspended the account. The
/// database raises `account_suspended`; no reason is shared with the person.
const String kSuspendedMessage =
    'Akun ini ditangguhkan, jadi kamu belum bisa masuk. Kalau kamu merasa ini '
    'keliru, hubungi tim admin di $kContactEmail.';

/// Whether [error] is the database refusing a suspended account.
bool isSuspendedError(Object? error) =>
    error.toString().contains('account_suspended');

/// A short, safe message for [error]. The error itself is not shown.
String friendlyError(Object? error) {
  if (error is TimeoutException) return kNetworkError;
  if (isSuspendedError(error)) return kSuspendedMessage;
  // Looked at only to choose a message, never displayed.
  final text = error.toString();
  if (RegExp(
    r'SocketException|ClientException|XMLHttpRequest|Failed host lookup|'
    r'Connection (refused|closed|reset)|Network is unreachable',
    caseSensitive: false,
  ).hasMatch(text)) {
    return kNetworkError;
  }
  return kGenericError;
}

/// Same, for "failed to load" screens: a message naming the thing that failed.
String friendlyLoadError(String thing, Object? error) {
  final network = friendlyError(error) == kNetworkError;
  return network
      ? "Couldn't load $thing. Check your connection and try again."
      : "Couldn't load $thing. Please try again.";
}
