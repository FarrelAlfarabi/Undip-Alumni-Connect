import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual identity drawn from the Ikafe UNDIP logo: yellow leads, black
/// anchors, blue informs (links and info only). Logo blue is #0096DE; it is too
/// light for text, so the UI uses the darker [blue] below.
class AppTheme {
  AppTheme._();

  static const yellow = Color(0xFFFFC400);
  static const black = Color(0xFF141414);
  static const blue = Color(0xFF0073B1);

  /// Darker yellow for text or icons on a light background (yellow itself is
  /// 1.5:1 there). Passes 4.5:1 on paper, raised paper and soft yellow.
  static const yellowText = Color(0xFF7A5800);

  /// Neutral greys for every surface. No cream and no blue tint, so the yellow,
  /// black and blue of the logo are the only colour on screen. Cards are white
  /// on [paper] and separated by a hairline, not by a second tint.
  static const paper = Color(0xFFF7F7F8);
  static const paperRaised = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFDCDDE0);
  static const ink = black;

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ).copyWith(
          primary: black,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE4F1F9),
          onPrimaryContainer: black,
          secondary: yellowText,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFFFF3C4),
          onSecondaryContainer: black,
          surface: paper,
          onSurface: ink,
          surfaceContainerLowest: paperRaised,
          surfaceContainerLow: paperRaised,
          surfaceContainer: paperRaised,
          surfaceContainerHigh: const Color(0xFFEBECEE),
          surfaceContainerHighest: const Color(0xFFE4E5E8),
          outlineVariant: hairline,
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
          backgroundColor: yellow,
          foregroundColor: black,
        ),
      ),
      // Cards are white with a hairline and no shadow, the same on every tab.
      cardTheme: CardThemeData(
        elevation: 0,
        color: paperRaised,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: hairline),
        ),
      ),
      // Filter chips: selected is black with white text, unselected is white
      // with a hairline. The default tap target keeps them at 48 dp.
      chipTheme: ChipThemeData(
        backgroundColor: paperRaised,
        selectedColor: black,
        disabledColor: paperRaised,
        surfaceTintColor: Colors.transparent,
        showCheckmark: false,
        side: const BorderSide(color: hairline),
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? Colors.white : ink,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: blue),
      ),
    );
  }
}
