/// The official Ikafe contacts and socials shown on Home > Kontak Ikafe.
/// The rows live in the `ikafe_contacts` table, which admins edit in the app
/// (Admin > Kontak Ikafe) or in the Supabase dashboard.
enum IkafeContactKind {
  whatsapp('WhatsApp'),
  email('Email'),
  instagram('Instagram'),
  linkedin('LinkedIn'),
  website('Website'),
  youtube('YouTube');

  const IkafeContactKind(this.title);

  /// Name used in the admin picker.
  final String title;

  /// The words on the open button in Kontak Ikafe.
  String get openLabel => switch (this) {
    IkafeContactKind.whatsapp => 'Chat WhatsApp',
    IkafeContactKind.email => 'Kirim email',
    IkafeContactKind.instagram => 'Buka Instagram',
    IkafeContactKind.linkedin => 'Buka LinkedIn',
    IkafeContactKind.website => 'Buka website',
    IkafeContactKind.youtube => 'Buka YouTube',
  };

  /// Instagram, LinkedIn and Website go under "Media sosial"; WhatsApp and
  /// Email go under "Hubungi".
  bool get isSocial => switch (this) {
    IkafeContactKind.whatsapp || IkafeContactKind.email => false,
    _ => true,
  };

  static IkafeContactKind? parse(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

class IkafeContact {
  const IkafeContact({
    required this.id,
    required this.kind,
    required this.label,
    required this.value,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final IkafeContactKind kind;
  final String label;

  /// Number with country code, email address, @handle or link.
  final String value;
  final int sortOrder;
  final bool active;

  /// Null when the row has a kind this app version does not know.
  static IkafeContact? tryFromMap(Map<String, dynamic> m) {
    final kind = IkafeContactKind.parse(m['kind'] as String?);
    if (kind == null) return null;
    return IkafeContact(
      id: m['id'].toString(),
      kind: kind,
      label: (m['label'] as String?) ?? '',
      value: (m['value'] as String?) ?? '',
      sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      active: (m['active'] as bool?) ?? true,
    );
  }

  factory IkafeContact.fromMap(Map<String, dynamic> m) => tryFromMap(m)!;

  /// The link that opens the right app for this contact.
  Uri get uri {
    final v = value.trim();
    switch (kind) {
      case IkafeContactKind.whatsapp:
        // A link (wa.me, a group invite) opens as it is.
        if (v.contains('/')) return _web(v);
        var digits = v.replaceAll(RegExp(r'[^0-9]'), '');
        // 0812... is an Indonesian number: wa.me needs 62812...
        if (digits.startsWith('0')) digits = '62${digits.substring(1)}';
        return Uri.parse('https://wa.me/$digits');
      case IkafeContactKind.email:
        return Uri(scheme: 'mailto', path: v);
      case IkafeContactKind.instagram:
        if (v.startsWith('@')) {
          return Uri.parse('https://www.instagram.com/${v.substring(1)}');
        }
        // A bare handle ("ikafeundip"), not a link.
        if (!v.contains('/') && !v.contains('.')) {
          return Uri.parse('https://www.instagram.com/$v');
        }
        return _web(v);
      case IkafeContactKind.linkedin:
      case IkafeContactKind.website:
      case IkafeContactKind.youtube:
        return _web(v);
    }
  }

  static Uri _web(String v) => Uri.parse(
    RegExp(r'^https?://', caseSensitive: false).hasMatch(v) ? v : 'https://$v',
  );
}

/// Shown only when the `ikafe_contacts` table does not exist yet (before the
/// migration is applied). Example values, not real contacts: the screen says so.
const List<IkafeContact> kPlaceholderIkafeContacts = [
  IkafeContact(
    id: 'placeholder-whatsapp',
    kind: IkafeContactKind.whatsapp,
    label: 'WhatsApp Ikafe',
    value: '+6200000000000',
    sortOrder: 1,
  ),
  IkafeContact(
    id: 'placeholder-email',
    kind: IkafeContactKind.email,
    label: 'Email Ikafe',
    value: 'kontak@ikafe.example',
    sortOrder: 2,
  ),
  IkafeContact(
    id: 'placeholder-instagram',
    kind: IkafeContactKind.instagram,
    label: 'Instagram Ikafe',
    value: '@ikafe_contoh',
    sortOrder: 3,
  ),
  IkafeContact(
    id: 'placeholder-linkedin',
    kind: IkafeContactKind.linkedin,
    label: 'LinkedIn Ikafe',
    value: 'linkedin.com/company/ikafe-contoh',
    sortOrder: 4,
  ),
  IkafeContact(
    id: 'placeholder-website',
    kind: IkafeContactKind.website,
    label: 'Website Ikafe',
    value: 'ikafe.example',
    sortOrder: 5,
  ),
  IkafeContact(
    id: 'placeholder-youtube',
    kind: IkafeContactKind.youtube,
    label: 'YouTube Ikafe',
    value: 'youtube.com/@ikafe-contoh',
    sortOrder: 6,
  ),
];
