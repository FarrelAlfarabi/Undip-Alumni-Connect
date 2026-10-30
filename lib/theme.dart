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

  /// Alerts and the unread badge. White text on it is 4.5:1 or better.
  static const danger = Color(0xFFD93025);

  /// Black pill button with white text (used on the business card). Apply with
  /// `FilledButton(style: AppTheme.blackPillButton, ...)`.
  static final blackPillButton = FilledButton.styleFrom(
    backgroundColor: black,
    foregroundColor: Colors.white,
    shape: const StadiumBorder(),
    textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
  );

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

    final baseText = GoogleFonts.plusJakartaSansTextTheme();
    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      displaySmall: baseText.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: black,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
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
        style: TextButton.styleFrom(
          foregroundColor: blue,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: hairline),
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: danger,
        textColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: yellow,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? black
                : colorScheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? black
                : colorScheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
