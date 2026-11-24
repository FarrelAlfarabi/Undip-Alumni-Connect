// English left on Indonesian screens (Farrel's screenshot, 24 Nov 2026):
// "Product posted. It is now visible in the marketplace." after posting,
// "All" in the Kategori filter, the business limit note, and the product
// dialogs. Feature names (Marketplace, Businesses, Jobs) stay in English.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_messages.dart';
import 'package:undip_alumni_connect/models/business.dart' show kMaxBusinesses;
import 'package:undip_alumni_connect/config/policy_config.dart';
import 'package:undip_alumni_connect/util/strings_id.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  test('every marketplace message has Indonesian text', () {
    for (final m in [
      kSubmittedMessage,
      kEditedBusinessMessage,
      kEditedApprovedMessage,
      kEditedMessage,
      kReportSentMessage,
      kProductsNeedBusinessMessage,
      kPostLimitMessage,
      'Product limit reached',
      'Register a business',
      'You have used {0} of {1} products for {2}.\n\n{3}',
    ]) {
      expect(kIndonesian.containsKey(m), isTrue, reason: m);
    }
  });

  test('the business limit note has Indonesian text', () {
    expect(
      kIndonesian.containsKey(
        'You can own up to $kMaxBusinesses businesses. To add more, email '
        '$kContactEmail.',
      ),
      isTrue,
    );
  });

  test('the messages go through tr() where they are shown', () {
    expect(
      _src('lib/screens/marketplace_form_screen.dart'),
      contains('Text(tr(message))'),
    );
    expect(
      _src('lib/screens/marketplace_report_sheet.dart'),
      contains('Text(tr(kReportSentMessage))'),
    );
    final mine = _src('lib/screens/my_businesses_screen.dart');
    expect(mine, contains('Text(tr(_limitNote))'));
    expect(mine, isNot(contains('[_limitNote]')));
    final market = _src('lib/screens/marketplace_screen.dart');
    expect(market, contains('title: Text(tr(title))'));
    expect(market, contains('content: Text(tr(body))'));
  });

  test('"All" in a Kategori filter shows as "Semua"', () {
    expect(
      _src('lib/widgets/searchable_choice.dart'),
      contains('DropdownMenuEntry<String>(value: o, label: tr(o))'),
    );
    expect(kIndonesian['All'], 'Semua');
  });
}
