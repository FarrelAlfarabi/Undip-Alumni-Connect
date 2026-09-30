import 'package:url_launcher/url_launcher.dart';

const int kMaxUrlLength = 500;

/// Parses [raw] as a web link, or returns null. Only `http` and `https` are
/// allowed, with a real host and no embedded username or password. A bare
/// `linkedin.com/in/someone` becomes `https://linkedin.com/in/someone`.
/// Everything else (`javascript:`, `tel:`, `sms:`, `intent:`, `file:`,
/// `data:`, `mailto:`, custom app schemes) is refused.
Uri? parseHttpUrl(String? raw) {
  var text = (raw ?? '').trim();
  if (text.isEmpty || text.length > kMaxUrlLength) return null;
  if (RegExp(r'\s').hasMatch(text)) return null;

  // "example.com/path" with no scheme: assume https.
  if (!text.contains('://') &&
      RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+(/.*)?$').hasMatch(text)) {
    text = 'https://$text';
  }

  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}

/// Form validator for a link field. Empty is fine unless [required].
String? validateHttpUrl(String? value, {bool required = false}) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return required ? 'Required by this job' : null;
  return parseHttpUrl(v) == null
      ? 'Enter a link that starts with http:// or https://'
      : null;
}

typedef UrlLauncher = Future<bool> Function(Uri uri);

Future<bool> openHttpUrlDefault(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Opens [raw] only if it is a safe web link. Returns false (and opens
/// nothing) otherwise, or if the launcher fails.
Future<bool> openHttpUrl(
  String? raw, {
  UrlLauncher launcher = openHttpUrlDefault,
}) async {
  final uri = parseHttpUrl(raw);
  if (uri == null) return false;
  try {
    return await launcher(uri);
  } catch (_) {
    return false;
  }
}
