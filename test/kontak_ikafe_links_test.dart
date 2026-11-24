// Kontak Ikafe link buttons (24 Nov 2026): every contact has a visible button
// that opens it (WhatsApp chat, email, Instagram, LinkedIn, website).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/ikafe_contact.dart';
import 'package:undip_alumni_connect/data/ikafe_contact_repository.dart';
import 'package:undip_alumni_connect/screens/kontak_ikafe_screen.dart';

class _Api implements IkafeContactApi {
  @override
  Future<List<Map<String, dynamic>>> activeRows() async => [
    {
      'id': 'w',
      'kind': 'whatsapp',
      'label': 'WhatsApp Ikafe',
      'value': '+62 812-3456-7890',
      'sort_order': 1,
    },
    {
      'id': 'e',
      'kind': 'email',
      'label': 'Email Ikafe',
      'value': 'kontak@ikafe.id',
      'sort_order': 2,
    },
    {
      'id': 'i',
      'kind': 'instagram',
      'label': 'Instagram',
      'value': '@ikafeundip',
      'sort_order': 3,
    },
    {
      'id': 'l',
      'kind': 'linkedin',
      'label': 'LinkedIn',
      'value': 'linkedin.com/company/ikafe',
      'sort_order': 4,
    },
    {
      'id': 's',
      'kind': 'website',
      'label': 'Website',
      'value': 'ikafe.id',
      'sort_order': 5,
    },
  ];
}

void main() {
  test('a WhatsApp group or wa.me link is opened as it is', () {
    IkafeContact c(String v) => IkafeContact.fromMap({
      'id': 'x',
      'kind': 'whatsapp',
      'label': 'L',
      'value': v,
    });
    expect(
      c('https://chat.whatsapp.com/AbCdEf123').uri.toString(),
      'https://chat.whatsapp.com/AbCdEf123',
    );
    expect(c('wa.me/628123').uri.toString(), 'https://wa.me/628123');
    expect(c('0812 3456').uri.toString(), 'https://wa.me/628123456');
  });

  test('an Instagram or LinkedIn handle without a link still opens', () {
    IkafeContact c(String kind, String v) => IkafeContact.fromMap({
      'id': 'x',
      'kind': kind,
      'label': 'L',
      'value': v,
    });
    expect(
      c('instagram', 'ikafeundip').uri.toString(),
      'https://www.instagram.com/ikafeundip',
    );
    expect(
      c('linkedin', 'https://www.linkedin.com/company/ikafe').uri.host,
      'www.linkedin.com',
    );
  });

  testWidgets('each contact has a button that opens its link', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: KontakIkafeScreen(
          repository: IkafeContactRepository(_Api()),
          launcher: (u) async {
            opened.add(u);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final labels = {
      'w': 'Chat WhatsApp',
      'e': 'Kirim email',
      'i': 'Buka Instagram',
      'l': 'Buka LinkedIn',
      's': 'Buka website',
    };
    for (final e in labels.entries) {
      final b = find.byKey(Key('ikafe-open-${e.key}'));
      expect(b, findsOneWidget);
      expect(
        find.descendant(of: b, matching: find.text(e.value)),
        findsOneWidget,
      );
      await tester.tap(b);
      await tester.pumpAndSettle();
    }
    expect(opened.map((u) => u.toString()), [
      'https://wa.me/6281234567890',
      'mailto:kontak@ikafe.id',
      'https://www.instagram.com/ikafeundip',
      'https://linkedin.com/company/ikafe',
      'https://ikafe.id',
    ]);
  });

  testWidgets('a link that cannot open offers to copy it', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: KontakIkafeScreen(
          repository: IkafeContactRepository(_Api()),
          launcher: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ikafe-open-e')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tidak bisa dibuka'), findsOneWidget);
  });
}
