import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/widgets/press_feedback.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

double _scaleOf(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  testWidgets('shrinks at once on touch down and returns on release', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        PressFeedback(
          child: SizedBox(key: const Key('box'), width: 100, height: 100),
        ),
      ),
    );
    expect(_scaleOf(tester), 1.0);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('box'))),
    );
    await tester.pump();
    expect(_scaleOf(tester), lessThan(1.0));
    await g.up();
    await tester.pump();
    expect(_scaleOf(tester), 1.0);
  });

  testWidgets('lets go when the finger starts to scroll', (tester) async {
    await tester.pumpWidget(
      _app(
        const PressFeedback(
          child: SizedBox(key: Key('box'), width: 100, height: 100),
        ),
      ),
    );
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('box'))),
    );
    await tester.pump();
    expect(_scaleOf(tester), lessThan(1.0));
    await g.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(_scaleOf(tester), 1.0);
    await g.up();
  });

  testWidgets('does not take the tap from the child', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        PressFeedback(
          child: ElevatedButton(
            onPressed: () => taps++,
            child: const Text('Go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('no movement when reduce motion is on', (tester) async {
    await tester.pumpWidget(
      _app(
        const PressFeedback(
          child: SizedBox(key: Key('box'), width: 100, height: 100),
        ),
        reduceMotion: true,
      ),
    );
    expect(find.byType(AnimatedScale), findsNothing);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('box'))),
    );
    await tester.pump();
    await g.up();
  });

  test('press animation is quick', () {
    expect(kPressDownDuration.inMilliseconds, lessThanOrEqualTo(100));
    expect(kPressUpDuration.inMilliseconds, lessThanOrEqualTo(150));
  });
}
