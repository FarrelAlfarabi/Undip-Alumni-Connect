import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/widgets/error_view.dart';

/// The "Send feedback" action on an error snackbar must open the feedback
/// sheet. The old code opened it with the ScaffoldMessenger's own context,
/// which sits above the Navigator, so showModalBottomSheet had no Navigator to
/// use. The earlier test only checked that the label was on screen.
void main() {
  Widget app(void Function(BuildContext) onGo) => MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: TextButton(onPressed: () => onGo(ctx), child: const Text('GO')),
      ),
    ),
  );

  testWidgets('tapping Send feedback on the snackbar opens the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        (ctx) => showErrorSnackBar(
          ctx,
          message: 'It failed',
          screen: 'Test',
          error: 'boom',
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SnackBarAction, 'Send feedback'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('feedback-what')), findsOneWidget);
  });

  testWidgets('the messenger variant (used after an await) opens it too', (
    tester,
  ) async {
    await tester.pumpWidget(
      app((ctx) {
        final messenger = ScaffoldMessenger.of(ctx);
        final navigator = Navigator.of(ctx);
        showErrorSnackBarOn(
          messenger,
          navigator: navigator,
          message: 'It failed',
          screen: 'Test',
          error: 'boom',
        );
      }),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SnackBarAction, 'Send feedback'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('feedback-what')), findsOneWidget);
  });
}
