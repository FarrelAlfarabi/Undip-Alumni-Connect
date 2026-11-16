import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/profile_columns.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

/// NIM was erased from the app and the database on 16 Nov 2026
/// (20261116180000_remove_nim.sql). Nothing in lib/ may read, show or send it.
void main() {
  test('profile column list has no nim and keeps the app columns', () {
    final cols = kProfileColumns.split(',').map((c) => c.trim()).toList();
    expect(cols, isNot(contains('nim')));
    for (final c in [
      'id',
      'name',
      'email',
      'faculty',
      'major',
      'graduation_year',
      'city',
      'industry',
      'company',
      'current_role',
      'verification_status',
      'deleted_at',
    ]) {
      expect(cols, contains(c));
    }
  });

  test('no file in lib/ or web/ mentions NIM', () {
    final word = RegExp(r'\bnim\b', caseSensitive: false);
    final offenders = <String>[];
    for (final dir in ['lib', 'web']) {
      for (final f
          in Directory(dir)
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (f) =>
                    f.path.endsWith('.dart') ||
                    f.path.endsWith('.js') ||
                    f.path.endsWith('.html'),
              )) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (word.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  testWidgets('own profile shows no NIM row', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileDetailScreen(
          profile: const {
            'id': 'p1',
            'name': 'Ahmad',
            'faculty': 'Ekonomika dan Bisnis',
          },
          currentUser: ValueNotifier<Map<String, dynamic>>({'id': 'p1'}),
          showEditButton: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NIM'), findsNothing);
    expect(find.text('Faculty'), findsOneWidget);
  });
}
