import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/widgets/filter_dropdown.dart';

void main() {
  group('SearchDebounce', () {
    testWidgets('waits for a pause in typing, then tells once', (tester) async {
      final c = TextEditingController();
      var settled = 0;
      final d = SearchDebounce(c, () => settled++);
      addTearDown(() {
        d.dispose();
        c.dispose();
      });

      c.text = 'k';
      await tester.pump(const Duration(milliseconds: 100));
      c.text = 'ko';
      await tester.pump(const Duration(milliseconds: 100));
      c.text = 'kop';
      await tester.pump(const Duration(milliseconds: 100));
      expect(settled, 0);

      await tester.pump(kSearchDelay);
      expect(settled, 1);
    });

    testWidgets('ignores caret moves that leave the text as it was', (
      tester,
    ) async {
      final c = TextEditingController(text: 'abc');
      var settled = 0;
      final d = SearchDebounce(c, () => settled++);
      addTearDown(() {
        d.dispose();
        c.dispose();
      });

      c.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump(kSearchDelay * 2);
      expect(settled, 0);
    });

    testWidgets('clearing the box tells at once', (tester) async {
      final c = TextEditingController(text: 'abc');
      var settled = 0;
      final d = SearchDebounce(c, () => settled++);
      addTearDown(() {
        d.dispose();
        c.dispose();
      });

      c.clear();
      expect(settled, 1);
    });

    testWidgets('a pending update is dropped after dispose', (tester) async {
      final c = TextEditingController();
      var settled = 0;
      final d = SearchDebounce(c, () => settled++);
      c.text = 'x';
      d.dispose();
      await tester.pump(kSearchDelay * 2);
      expect(settled, 0);
      c.dispose();
    });
  });
}
