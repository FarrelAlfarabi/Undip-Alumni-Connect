import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Picks [name] in the searchable Category field of the product or business
/// form.
Future<void> chooseCategory(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('category-choice')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}
