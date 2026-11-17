import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_config.dart';
import 'package:undip_alumni_connect/lock/pin_pad.dart';
import 'package:undip_alumni_connect/lock/app_entry.dart';
import 'package:undip_alumni_connect/screens/admin_log_screen.dart';
import 'package:undip_alumni_connect/screens/contact_admin_screen.dart';

void main() {
  testWidgets('the PIN can be typed with the keyboard', (tester) async {
    String? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PinPad(onCompleted: (p) async => got = p)),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.pump();
    expect(kPinLength, 6);
    expect(got, '134567');
  });

  testWidgets('a suspended member sees their own text, no alumni form', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactAdminScreen(
          fromLogin: true,
          suspended: true,
          alumniFormUrl: 'https://example.com/form',
        ),
      ),
    );
    expect(find.textContaining('Akunmu ditangguhkan'), findsOneWidget);
    expect(find.byKey(const Key('alumni-form-open')), findsNothing);
    expect(find.textContaining('Yuk isi database'), findsNothing);
  });

  test('login notices are Indonesian', () {
    for (final n in [
      kSignInFailedNotice,
      kSessionExpiredNotice,
      kTooManyPinsNotice,
    ]) {
      expect(n, isNot(contains('Please')));
      expect(n, isNot(contains('sign in')));
    }
  });

  test('Riwayat shows a readable label for report actions', () {
    expect(adminActionLabel('report_dismiss'), 'Laporan diabaikan');
    expect(adminActionLabel('report_whatever'), 'Laporan diproses');
  });
}
