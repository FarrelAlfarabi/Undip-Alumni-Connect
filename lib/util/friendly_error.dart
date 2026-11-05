import 'dart:async';

import '../config/policy_config.dart';
import 'app_language.dart';

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

/// Shown when the email service refuses to send another login code for now.
const String kCodeRateLimited =
    'Terlalu banyak permintaan kode. Tunggu beberapa menit, lalu coba lagi.';

/// Shown after five wrong codes in a row. A new code is needed.
const String kTooManyCodeAttempts =
    'Terlalu banyak kode yang salah. Minta kode baru untuk lanjut.';

/// Shown when the database refuses a new job post (too many).
const String kJobLimitMessage =
    'Kamu sudah memasang terlalu banyak lowongan. Maksimal 5 per hari dan '
    '20 lowongan aktif. Tutup atau hapus yang lama dulu.';

/// Whether [error] is the email service saying "too many codes requested".
bool isRateLimitError(Object? error) {
  final text = error.toString().toLowerCase();
  return text.contains('over_email_send_rate_limit') ||
      text.contains('over_request_rate_limit') ||
      text.contains('rate limit') ||
      text.contains('statuscode: 429');
}

/// Whether [error] is the database refusing a suspended account.
bool isSuspendedError(Object? error) =>
    error.toString().contains('account_suspended');

/// A short, safe message for [error]. The error itself is not shown.
String friendlyError(Object? error) {
  if (error is TimeoutException) return tr(kNetworkError);
  if (isSuspendedError(error)) return tr(kSuspendedMessage);
  // Looked at only to choose a message, never displayed.
  final text = error.toString();
  if (text.contains('job_daily_limit') || text.contains('job_open_limit')) {
    return tr(kJobLimitMessage);
  }
  if (text.contains('job_closed')) return tr('Lowongan ini sudah ditutup.');
  if (RegExp(
    r'SocketException|ClientException|XMLHttpRequest|Failed host lookup|'
    r'Connection (refused|closed|reset)|Network is unreachable',
    caseSensitive: false,
  ).hasMatch(text)) {
    return tr(kNetworkError);
  }
  return tr(kGenericError);
}

/// Same, for "failed to load" screens: a message naming the thing that failed.
String friendlyLoadError(String thing, Object? error) {
  final network = friendlyError(error) == tr(kNetworkError);
  final id =
      AppLanguage.shared.current.value == AppLang.id &&
      !AppLanguage.shared.passthrough;
  if (id) {
    return network
        ? 'Gagal memuat $thing. Periksa koneksimu lalu coba lagi.'
        : 'Gagal memuat $thing. Coba lagi.';
  }
  return network
      ? "Couldn't load $thing. Check your connection and try again."
      : "Couldn't load $thing. Please try again.";
}
