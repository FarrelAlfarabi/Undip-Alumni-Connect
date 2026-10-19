import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/profile_columns.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

/// 20261018120000_hide_nim.sql removes the nim column from what the API roles
/// can read. The app must name its columns and ask profile_nim() for NIM.
Widget _screen({
  required String viewerId,
  required Future<String?> Function(String viewerId, String profileId) loader,
}) {
  return MaterialApp(
    home: ProfileDetailScreen(
      profile: {
        'id': 'p1',
        'name': 'Ahmad',
        'nim': '21120112130001',
        'faculty': 'Ekonomika dan Bisnis',
      },
      currentUser: ValueNotifier<Map<String, dynamic>>({'id': viewerId}),
      showEditButton: false,
      nimLoader: loader,
    ),
  );
}

void main() {
  test('profile column list leaves out nim and keeps the app columns', () {
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

  test('no read of alumni_profiles uses select() or filters on nim', () {
    final offenders = <String>[];
    final bare = RegExp(
      r"from\('alumni_profiles'\)[^;]*?\.select\(\s*\)",
      dotAll: true,
    );
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      if (bare.hasMatch(text)) offenders.add('${f.path}: bare select()');
      if (text.contains(".eq('nim'")) offenders.add('${f.path}: eq nim');
    }
    expect(offenders, isEmpty);
  });

  testWidgets('another member\'s NIM is not shown', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _screen(viewerId: 'other', loader: (_, _) async => null),
    );
    await tester.pumpAndSettle();
    expect(find.text('NIM'), findsNothing);
    expect(find.text('21120112130001'), findsNothing);
    expect(find.text('Faculty'), findsOneWidget);
  });

  testWidgets('NIM shows when the database returns it (own profile, admin)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? asked;
    await tester.pumpWidget(
      _screen(
        viewerId: 'p1',
        loader: (viewer, profile) async {
          asked = '$viewer>$profile';
          return '21120112130001';
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(asked, 'p1>p1');
    expect(find.text('NIM'), findsOneWidget);
    expect(find.text('21120112130001'), findsOneWidget);
  });

  testWidgets('a failing NIM lookup just hides NIM', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _screen(viewerId: 'p1', loader: (_, _) async => throw Exception('x')),
    );
    await tester.pumpAndSettle();
    expect(find.text('NIM'), findsNothing);
    expect(find.text('Faculty'), findsOneWidget);
  });
}
