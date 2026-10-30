import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:undip_alumni_connect/theme.dart';

/// The app's fonts ship inside the app (assets/fonts). With runtime fetching
/// off, google_fonts can only succeed if it finds them there, so this fails if
/// a file goes missing or a new weight is used without being bundled. Without
/// it the app would quietly go back to downloading fonts on first launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // google_fonts does not throw when a font is missing, it only prints.
  final printed = <String>[];
  final realDebugPrint = debugPrint;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    printed.clear();
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
  });
  tearDown(() {
    GoogleFonts.config.allowRuntimeFetching = true;
    debugPrint = realDebugPrint;
  });

  test('the theme text styles load from bundled fonts', () async {
    final theme = AppTheme.light();
    final styles = <TextStyle?>[
      for (final w in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
        FontWeight.w800,
      ])
        GoogleFonts.plusJakartaSans(fontWeight: w),
      theme.textTheme.bodyMedium,
      theme.textTheme.titleLarge,
      theme.appBarTheme.titleTextStyle,
    ];
    expect(styles.every((s) => s != null), isTrue);
    await GoogleFonts.pendingFonts();
    expect(printed.where((m) => m.contains('unable to load font')), isEmpty);
  });

  test('the theme uses Plus Jakarta Sans and headlines are w700', () {
    final t = AppTheme.light().textTheme;
    expect(t.bodyMedium!.fontFamily, contains('PlusJakartaSans'));
    expect(t.titleLarge!.fontFamily, contains('PlusJakartaSans'));
    expect(t.titleLarge!.fontWeight, FontWeight.w700);
    expect(t.headlineMedium!.fontWeight, FontWeight.w700);
  });

  test('the old font files are gone and the new ones are bundled', () {
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      expect(File('assets/fonts/PlusJakartaSans-$w.ttf').existsSync(), isTrue);
    }
    final left = Directory('assets/fonts')
        .listSync()
        .map((f) => f.path)
        .where((p) => p.contains('Fraunces') || p.contains('IBMPlex'));
    expect(left, isEmpty);
  });
}
