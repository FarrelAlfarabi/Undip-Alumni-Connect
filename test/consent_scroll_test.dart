import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/policy/consent_screen.dart';

/// Serves one fixed text for every asset key.
class _TextBundle extends CachingAssetBundle {
  _TextBundle(this.text);
  final String text;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
}

String _longPolicy() =>
    '# Title\n${List.generate(80, (i) => 'Paragraph $i of the policy text.\n').join()}';

Future<void> _pump(WidgetTester tester, String text) async {
  tester.view.physicalSize = const Size(420, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ConsentScreen(
        profile: const {'id': 'me', 'name': 'Siti'},
        onAccepted: (_, _) {},
        bundle: _TextBundle(text),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CheckboxListTile _box(WidgetTester tester) =>
    tester.widget(find.byKey(const Key('consent-checkbox')));

void main() {
  testWidgets('long text: the box stays off until the bottom is reached', (
    tester,
  ) async {
    await _pump(tester, _longPolicy());
    expect(_box(tester).onChanged, isNull);
    expect(find.byKey(const Key('consent-scroll-hint')), findsOneWidget);

    // Part of the way down is not enough.
    await tester.drag(
      find.byKey(const Key('policy-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(_box(tester).onChanged, isNull);

    await tester.drag(
      find.byKey(const Key('policy-scroll')),
      const Offset(0, -20000),
    );
    await tester.pumpAndSettle();
    expect(_box(tester).onChanged, isNotNull);
    expect(find.byKey(const Key('consent-scroll-hint')), findsNothing);

    await tester.tap(find.byKey(const Key('consent-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('consent-continue')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('short text that fits on screen does not lock the box', (
    tester,
  ) async {
    await _pump(tester, '# Title\nOne short paragraph.');
    expect(_box(tester).onChanged, isNotNull);
    expect(find.byKey(const Key('consent-scroll-hint')), findsNothing);
  });

  testWidgets(
    'switching language after reaching the bottom keeps it unlocked',
    (tester) async {
      await _pump(tester, _longPolicy());
      await tester.drag(
        find.byKey(const Key('policy-scroll')),
        const Offset(0, -20000),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('policy-scroll')),
        const Offset(0, 20000),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(_box(tester).onChanged, isNotNull);
    },
  );
}
