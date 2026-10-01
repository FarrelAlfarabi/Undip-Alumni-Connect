/// `farrel@gmail.com` -> `f***@gmail.com`. Shows the first letter of the
/// local part and the domain, nothing else. A one-letter local part shows
/// only `*`. Input without a usable `@` gives `***`.
String maskEmail(String email) {
  final at = email.lastIndexOf('@');
  if (at <= 0 || at == email.length - 1) return '***';
  final local = email.substring(0, at);
  final domain = email.substring(at + 1);
  final first = local.length > 1 ? local[0] : '*';
  return '$first***@$domain';
}

/// Up to two initials from a display name, upper case. `?` if empty.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}
