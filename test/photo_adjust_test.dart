import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_image_picker.dart';
import 'package:undip_alumni_connect/screens/photo_adjust_screen.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<void> load(WidgetTester tester) async {
  // Wait (in real time) until the photo has been decoded.
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pump(const Duration(seconds: 1));
}

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
    await load(tester);
    expect(find.byKey(const Key('photo-adjust-frame')), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.textContaining('Geser'), findsOneWidget);
  });

  group('crop math', () {
    const photo = Size(4000, 3000); // landscape 4:3
    const frame = Size(300, 200); // 3:2
    test('starts covering the frame, centered', () {
      final v = startCrop(photo, frame);
      expect(v.scale, closeTo(0.075, 1e-9)); // width fits: 300/4000
      expect(v.offset.dx, closeTo(0, 1e-9));
      expect(v.offset.dy, closeTo((200 - 3000 * 0.075) / 2, 1e-9));
    });
    test('cannot zoom out below cover or leave empty space', () {
      final v = clampCrop(photo, frame, 0.01, const Offset(500, 500));
      expect(v.scale, coverScale(photo, frame));
      expect(v.offset.dx, 0);
      expect(v.offset.dy, 0);
      final w = clampCrop(photo, frame, 0.075, const Offset(-900, -900));
      expect(w.offset.dy, closeTo(200 - 3000 * 0.075, 1e-9));
    });
    test('zoom is capped at 6x cover', () {
      expect(
        clampCrop(photo, frame, 5, Offset.zero).scale,
        closeTo(0.45, 1e-9),
      );
    });
    test('the whole tall photo can be reached, not pre-cut', () {
      const tall = Size(1000, 3000);
      final top = clampCrop(tall, frame, coverScale(tall, frame), Offset.zero);
      final bottom = clampCrop(
        tall,
        frame,
        coverScale(tall, frame),
        const Offset(0, -99999),
      );
      expect(top.offset.dy, 0);
      expect(bottom.offset.dy, closeTo(200 - 3000 * 0.3, 1e-9));
    });
  });

  testWidgets('double tap zooms in, then resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoAdjustScreen(
          image: PickedImage(name: 'a.png', bytes: png),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await load(tester);
    final area = find.byKey(const Key('photo-adjust-area'));
    expect(area, findsOneWidget);
    Future<void> doubleTap() async {
      await tester.tap(area);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(area);
      await load(tester);
    }

    await doubleTap();
    await doubleTap();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel and Save buttons sit above the bottom bar', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 60);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoAdjustScreen(
          image: PickedImage(name: 'a.png', bytes: png),
        ),
      ),
    );
    await load(tester);
    final bottom = tester
        .getBottomLeft(find.byKey(const Key('photo-adjust-save')))
        .dy;
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      bottom,
      lessThanOrEqualTo(screen - 60 / tester.view.devicePixelRatio),
    );
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
    await load(tester);
    await tester.tap(find.text('Batal'));
    await load(tester);
    expect(result, isNull);
  });

  testWidgets('Simpan returns a resized JPEG', (tester) async {
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
    await load(tester);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(find.byKey(const Key('photo-adjust-save')));
    });
    for (var i = 0; i < 40 && result == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.name, 'foto.jpg');
    expect(result!.bytes.sublist(0, 2), [0xFF, 0xD8]);
    expect(result!.bytes.length, greaterThan(8));
  });
}
