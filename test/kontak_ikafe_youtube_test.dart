// Kontak Ikafe gets a YouTube kind (26 Nov 2026).
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/ikafe_contact.dart';

void main() {
  test('youtube kind parses, opens a web link and is a social', () {
    expect(IkafeContactKind.parse('youtube'), IkafeContactKind.youtube);
    expect(IkafeContactKind.youtube.title, 'YouTube');
    expect(IkafeContactKind.youtube.openLabel, 'Buka YouTube');
    expect(IkafeContactKind.youtube.isSocial, isTrue);
    final c = IkafeContact.fromMap({
      'id': 'y',
      'kind': 'youtube',
      'label': 'YouTube',
      'value': 'https://www.youtube.com/@IkafeTV',
    });
    expect(c.uri.toString(), 'https://www.youtube.com/@IkafeTV');
  });

  test('youtube value without scheme gets https', () {
    final c = IkafeContact.fromMap({
      'id': 'y',
      'kind': 'youtube',
      'label': 'YouTube',
      'value': 'youtube.com/@IkafeTV',
    });
    expect(c.uri.toString(), 'https://youtube.com/@IkafeTV');
  });
}
