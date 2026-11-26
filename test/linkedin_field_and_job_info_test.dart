import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/profile_fields.dart';
import 'package:undip_alumni_connect/screens/profile_linkedin_screen.dart';
import 'package:undip_alumni_connect/screens/profile_setup_screen.dart';
import 'package:undip_alumni_connect/theme.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('LinkedIn field has no length formatter or suggestion flags', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProfileLinkedInScreen(profile: const {'id': 'me'}),
      ),
    );
    final field = tester.widget<TextField>(
      find.byKey(const Key('linkedin-field')),
    );
    // These made Android browsers repeat typed characters.
    expect(field.maxLength, isNull);
    expect(field.enableSuggestions, isTrue);
    expect(field.keyboardType, kUrlKeyboard);
    expect(field.inputFormatters ?? const [], isEmpty);
  });

  testWidgets('LinkedIn link longer than 200 characters is refused on save', (
    tester,
  ) async {
    phone(tester);
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProfileLinkedInScreen(
          profile: const {'id': 'me'},
          save: (id, c) async {
            saved = true;
            return {'id': id, ...c};
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('linkedin-field')),
      'linkedin.com/in/${'a' * 250}',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(find.byKey(const Key('linkedin-error')), findsOneWidget);
  });

  testWidgets('Job info screen saves through the injected saver', (
    tester,
  ) async {
    phone(tester);
    Map<String, dynamic>? sent;
    Map<String, dynamic>? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(
                  builder: (_) => ProfileSetupScreen(
                    profile: const {'id': 'me', 'name': 'Rani'},
                    save: (id, changes) async {
                      sent = changes;
                      return {'id': id, ...changes};
                    },
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Analis');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(sent?['current_role'], 'Analis');
    expect(popped?['current_role'], 'Analis');
  });

  test('merging a saved profile keeps fields the save does not return', () {
    expect(
      mergeSavedProfile(
        {'id': 'me', 'avatar_url': 'a.jpg', 'current_role': ''},
        {'id': 'me', 'current_role': 'Analis'},
      ),
      {'id': 'me', 'avatar_url': 'a.jpg', 'current_role': 'Analis'},
    );
  });
}
