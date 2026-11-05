import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/screens/settings_screen.dart';
import 'package:undip_alumni_connect/util/app_language.dart';
import 'package:undip_alumni_connect/util/friendly_error.dart';

void main() {
  final app = AppLanguage.shared;
  setUp(() {
    app.passthrough = false;
    app.store = MemoryLockStore();
    app.current.value = AppLang.id;
  });
  tearDown(() {
    app.passthrough = true;
    app.current.value = AppLang.id;
  });

  test('Indonesian is the default and English texts get Indonesian', () {
    expect(tr('Pengaturan'), 'Pengaturan');
    expect(friendlyError(Exception('x')), 'Terjadi kesalahan. Coba lagi.');
    expect(
      businessErrorMessage(
        const BusinessException(BusinessErrorCode.notFound, 'x'),
      ),
      'Bisnis ini sudah tidak ada.',
    );
  });

  test('English gives English; unknown text stays as written', () {
    app.current.value = AppLang.en;
    expect(tr('Pengaturan'), 'Settings');
    expect(
      friendlyError(Exception('x')),
      'Something went wrong. Please try again.',
    );
    expect(tr('Teks yang belum ada'), 'Teks yang belum ada');
  });

  test('the choice is saved and read back', () async {
    final store = MemoryLockStore();
    await app.set(AppLang.en, store);
    expect(store.data['app_language'], 'en');
    app.current.value = AppLang.id;
    await app.load(store);
    expect(app.current.value, AppLang.en);
  });

  testWidgets('Settings has a language choice that switches the screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          showPin: false,
        ),
      ),
    );
    expect(find.text('Pengaturan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-en')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Blocked users'), findsOneWidget);
  });
}
