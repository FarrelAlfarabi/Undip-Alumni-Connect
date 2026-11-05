import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_image_picker.dart';
import 'package:undip_alumni_connect/screens/photo_adjust_screen.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  tearDown(() => PhotoAdjust.enabled = false);

  test('disabled: the photo passes through untouched', () async {
    PhotoAdjust.enabled = false;
    final img = PickedImage(name: 'a.png', bytes: png);
    // No context is needed when it is off.
    expect(await PhotoAdjust.run(null, img), same(img));
  });

  testWidgets('shows the photo in a frame with Simpan and Batal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoAdjustScreen(
          image: PickedImage(name: 'a.png', bytes: png),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-adjust-frame')), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.textContaining('Geser'), findsOneWidget);
  });

  testWidgets('can zoom out below the frame and move freely, on white', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoAdjustScreen(
          image: PickedImage(name: 'a.png', bytes: png),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.minScale, lessThan(1));
    expect(viewer.boundaryMargin, const EdgeInsets.all(double.infinity));
    final frame = tester.widget<ColoredBox>(
      find.byKey(const Key('photo-adjust-frame')),
    );
    expect(frame.color, Colors.white);
    // Zoomed out, the photo is smaller than the frame.
    final controller = viewer.transformationController!;
    controller.value = Matrix4.diagonal3Values(0.5, 0.5, 1);
    await tester.pump();
    expect(controller.value.entry(0, 0), 0.5);
  });

  testWidgets('Batal closes without a photo', (tester) async {
    PhotoAdjust.enabled = true;
    PickedImage? result = PickedImage(name: 'x', bytes: png);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await PhotoAdjust.run(
              context,
              PickedImage(name: 'a.png', bytes: png),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('Simpan returns a cropped PNG', (tester) async {
    PhotoAdjust.enabled = true;
    PickedImage? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await PhotoAdjust.run(
              context,
              PickedImage(name: 'foto.jpg', bytes: png),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('photo-adjust-save')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.name, 'foto.png');
    expect(result!.bytes.length, greaterThan(8));
  });
}
