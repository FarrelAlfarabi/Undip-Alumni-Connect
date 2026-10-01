/// Form validators for the marketplace listing form. Each returns an error
/// message, or null when the value is fine. They mirror the database
/// constraints so users see the problem before a round trip.
class MarketplaceValidation {
  MarketplaceValidation._();

  static const maxPriceIdr = 2000000000; // stays under the integer column max

  static String? title(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (t.length < 3) return 'Title must be at least 3 characters';
    if (t.length > 100) return 'Title must be 100 characters or fewer';
    return null;
  }

  static String? description(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (t.length > 2000) return 'Description must be 2000 characters or fewer';
    return null;
  }

  /// Whole rupiah, digits only.
  static String? price(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    final n = int.tryParse(t);
    if (n == null || n < 0) return 'Enter a whole number, 0 or more';
    if (n > maxPriceIdr) return 'Price is too large';
    return null;
  }

  static String? city(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (t.length > 60) return 'City must be 60 characters or fewer';
    return null;
  }

  static String? category(String? v) =>
      (v == null || v.isEmpty) ? 'Choose a category' : null;

  /// Optional. When present it must be a valid http(s) link.
  static String? shopUrl(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final uri = Uri.tryParse(t);
    final ok =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.') &&
        !t.contains(RegExp(r'\s'));
    return ok ? null : 'Enter a valid link starting with http:// or https://';
  }

  /// The seller must give a shop link, contact info, or both.
  static String? shopOrContact(String? shop, String? contact) {
    final hasShop = (shop ?? '').trim().isNotEmpty;
    final hasContact = (contact ?? '').trim().isNotEmpty;
    return (hasShop || hasContact)
        ? null
        : 'Add a shop link or contact info (at least one)';
  }
}
