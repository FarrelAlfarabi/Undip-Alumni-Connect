import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/profile_city_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';
import 'package:undip_alumni_connect/theme.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('my profile has its own Ubah for City, others do not', (
    tester,
  ) async {
    phone(tester);
    Future<void> pump({required bool own}) async {
      final profile = {'id': 'me', 'name': 'Rani', 'city': 'Semarang'};
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ProfileDetailScreen(
            profile: profile,
            currentUser: ValueNotifier(own ? profile : {'id': 'x'}),
            showEditButton: own,
            chat: false,
            adminCheck: (_) async => false,
            nimLoader: (_, _) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(own: true);
    expect(find.byKey(const Key('profile-city')), findsOneWidget);
    expect(find.byKey(const Key('edit-city')), findsOneWidget);
    await pump(own: false);
    expect(find.byKey(const Key('edit-city')), findsNothing);
  });

  testWidgets('City screen saves only the city', (tester) async {
    phone(tester);
    Map<String, dynamic>? sent;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProfileCityScreen(
          profile: const {'id': 'me', 'city': 'Semarang'},
          save: (id, changes) async {
            sent = changes;
            return {'id': id, ...changes};
          },
        ),
      ),
    );
    final field = find.descendant(
      of: find.byKey(const Key('city-field')),
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Surabaya');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MenuItemButton).hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(sent, {'city': 'Surabaya'});
  });

  testWidgets('City screen shows an Indonesian error when save fails', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProfileCityScreen(
          profile: const {'id': 'me', 'city': 'Semarang'},
          save: (id, changes) async => throw Exception('boom'),
        ),
      ),
    );
    final field = find.descendant(
      of: find.byKey(const Key('city-field')),
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Surabaya');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MenuItemButton).hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('city-error')), findsOneWidget);
  });
}
