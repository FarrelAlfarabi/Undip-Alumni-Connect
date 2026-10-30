import 'policy_config.dart';

enum SupportContactKind { email, whatsapp, phone }

class SupportContact {
  const SupportContact(this.kind, this.label, this.value);

  final SupportContactKind kind;
  final String label;

  /// Email address, or phone number with country code (digits and a leading +).
  final String value;

  /// The link that opens the right app for this contact.
  Uri get uri => switch (kind) {
    SupportContactKind.email => Uri(scheme: 'mailto', path: value),
    SupportContactKind.whatsapp => Uri.parse(
      'https://wa.me/${value.replaceAll(RegExp(r'[^0-9]'), '')}',
    ),
    SupportContactKind.phone => Uri(scheme: 'tel', path: value),
  };

  /// Like [uri], with a subject and body filled in for an email contact.
  /// Other kinds ignore them.
  Uri uriWith({String? subject, String? body}) {
    if (kind != SupportContactKind.email) return uri;
    final q = {'subject': ?subject, 'body': ?body};
    return Uri(
      scheme: 'mailto',
      path: value,
      queryParameters: q.isEmpty ? null : q,
    );
  }
}

/// How to reach the admin / customer service team. Shown on
/// Profile > Contact admin. To add a WhatsApp or phone line, add one entry,
/// for example:
///   SupportContact(SupportContactKind.whatsapp, 'WhatsApp', '+628123456789')
const List<SupportContact> kSupportContacts = [
  SupportContact(SupportContactKind.email, 'Email', kContactEmail),
];
