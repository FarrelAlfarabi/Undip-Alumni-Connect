/// Cleans an error before it is sent as feedback. Removes emails, keys and
/// tokens, URLs, phone numbers and other long digit strings, ids, and stack
/// traces. Keeps only a short summary (at most [maxLength] characters).
///
/// The error itself is never shown to the person (see friendly_error.dart);
/// this cleaned summary is what the feedback report carries.
const int kErrorTextMax = 300;

String cleanErrorText(Object? error, {int maxLength = kErrorTextMax}) {
  var text = error?.toString() ?? '';
  if (text.trim().isEmpty) return '';

  // Keep only the lines before a stack trace starts.
  final kept = <String>[];
  for (final line in text.split('\n')) {
    final l = line.trim();
    if (l.isEmpty) continue;
    if (RegExp(r'^#\d+\s').hasMatch(l) ||
        RegExp(r'^at\s').hasMatch(l) ||
        RegExp(r'\(package:[^)]*\)|\(dart:[^)]*\)|\.dart:\d+').hasMatch(l)) {
      break;
    }
    kept.add(l);
  }
  text = kept.join(' ');

  text = text
      // emails
      .replaceAll(
        RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'),
        '[email]',
      )
      // every URL (a query string can carry a key)
      .replaceAll(
        RegExp(r'(https?|wss?)://\S+', caseSensitive: false),
        '[link]',
      )
      // JWTs, Supabase keys, bearer tokens
      .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+'),
        '[key]',
      )
      .replaceAll(
        RegExp(
          r'sb_(publishable|secret)_[A-Za-z0-9_\-]*',
          caseSensitive: false,
        ),
        '[key]',
      )
      .replaceAll(RegExp(r'Bearer\s+\S+', caseSensitive: false), '[key]')
      .replaceAll(
        RegExp(
          r'(apikey|api_key|token|secret|password)\s*[:=]\s*\S+',
          caseSensitive: false,
        ),
        '[key]',
      )
      // ids
      .replaceAll(
        RegExp(
          r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
        ),
        '[id]',
      )
      // long random strings (hex or base64 like)
      .replaceAllMapped(RegExp(r'[A-Za-z0-9_\-]{24,}'), (m) {
        final s = m[0]!;
        return RegExp(r'\d').hasMatch(s) && RegExp(r'[A-Za-z]').hasMatch(s)
            ? '[key]'
            : s;
      })
      // phone numbers with separators, then any other long digit string
      .replaceAll(RegExp(r'\+?\d[\d\s\-().]{6,}\d'), '[number]')
      .replaceAll(RegExp(r'\d{6,}'), '[number]');

  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length > maxLength) {
    text = '${text.substring(0, maxLength - 1).trimRight()}…';
  }
  return text;
}
