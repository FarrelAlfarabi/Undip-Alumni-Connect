import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/pin_pad.dart';

/// The pad shows up after a button was pressed (settings steps), so that
/// button owns the keyboard focus. The keyboard must still type the PIN.
void main() {
  testWidgets('keyboard works when the pad appears after a button press', (
    tester,
  ) async {
    String? got;
    var showPad = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  key: const Key('open'),
                  onPressed: () => setState(() => showPad = true),
                  child: const Text('Ubah PIN'),
                ),
                if (showPad) PinPad(onCompleted: (p) async => got = p),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    for (final k in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ]) {
      await tester.sendKeyEvent(k);
    }
    await tester.pump();
    expect(got, '123456');
  });

  testWidgets('clicking the pad takes the keyboard back', (tester) async {
    String? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TextField(key: Key('field')),
              PinPad(onCompleted: (p) async => got = p),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    await tester.tap(find.text('1'));
    await tester.pump();
    for (final k in [
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ]) {
      await tester.sendKeyEvent(k);
    }
    await tester.pump();
    expect(got, '123456');
  });
}
