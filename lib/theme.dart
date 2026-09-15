import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Placeholder visual identity — indigo/brass, drawn from Javanese batik
/// (kawung motif, indigo-dyed cloth, brass/gold prada gilding). Not UNDIP's
/// or ILUNI's official branding; a working stand-in for the demo/pitch.
/// Matches the pitch landing page's palette and type pairing.
class AppTheme {
  AppTheme._();

  static const indigo = Color(0xFF2E2A5C);
  static const gold = Color(0xFF9C6E22);
  static const paper = Color(0xFFF7F3E8);
  static const paperRaised = Color(0xFFEDE6D2);
  static const ink = Color(0xFF211D3C);

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: indigo,
          brightness: Brightness.light,
        ).copyWith(
          primary: indigo,
          onPrimary: const Color(0xFFFAF6EA),
          primaryContainer: const Color(0xFFE7E2F2),
          onPrimaryContainer: indigo,
          secondary: gold,
          onSecondary: const Color(0xFFFAF6EA),
          secondaryContainer: const Color(0xFFF1E4C9),
          onSecondaryContainer: const Color(0xFF6B4B17),
          surface: paper,
          onSurface: ink,
          surfaceContainerLowest: const Color(0xFFFAF6EA),
          surfaceContainer: paperRaised,
          surfaceContainerHigh: const Color(0xFFE7DFC6),
        );

    final baseText = GoogleFonts.ibmPlexSansTextTheme();
    final textTheme = baseText.copyWith(
      displayLarge: GoogleFonts.fraunces(
        textStyle: baseText.displayLarge,
        fontWeight: FontWeight.w600,
      ),
      displayMedium: GoogleFonts.fraunces(
        textStyle: baseText.displayMedium,
        fontWeight: FontWeight.w600,
      ),
      displaySmall: GoogleFonts.fraunces(
        textStyle: baseText.displaySmall,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: GoogleFonts.fraunces(
        textStyle: baseText.headlineLarge,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.fraunces(
        textStyle: baseText.headlineMedium,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.fraunces(
        textStyle: baseText.headlineSmall,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.fraunces(
        textStyle: baseText.titleLarge,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.ibmPlexSans(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
        ),
      ),
    );
  }
}
