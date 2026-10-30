import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/platform/breakpoints.dart';
import 'package:undip_alumni_connect/widgets/responsive_page.dart';

Future<void> _pump(WidgetTester t, double w, Widget child) async {
  t.view.physicalSize = Size(w, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  for (final c in [
    (390.0, ScreenStep.phone, 390.0),
    (768.0, ScreenStep.tablet, 720.0),
    (1280.0, ScreenStep.desktop, 960.0),
  ]) {
    testWidgets('at ${c.$1}: ${c.$2.name}, content ${c.$3}', (t) async {
      ScreenStep? seen;
      await _pump(
        t,
        c.$1,
        ResponsivePage(builder: (ctx, step) {
          seen = step;
          return Container(key: const Key('body'));
        }),
      );
      expect(seen, c.$2);
      expect(t.getSize(find.byKey(const Key('body'))).width, c.$3);
      expect(t.takeException(), isNull);
    });
  }
}
