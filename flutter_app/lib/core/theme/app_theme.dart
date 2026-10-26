import 'package:flutter/material.dart';

/// "Claude Duet" Editorial & Minimalist Government Theme for NidanIQ Nepal Sovereign DPI.
/// Warm stone canvas (#ECEAE4), dark slate cards (#0F172A), Outbreak Crimson (#DC2626),
/// and Contained Emerald (#10B981).
///
/// Honors Pillar 3 (Official Nepali Typography & Inclusive Accessibility):
/// - Unicode-compliant Devanagari rendering (`Noto Sans Devanagari` / `Kalimati` fallbacks)
///   with generous line height (`1.45`) so Devanagari matras never clip.
/// - Guaranteed minimum `48dp x 48dp` touch targets (`MaterialTapTargetSize.padded`)
///   for older FCHVs and field health workers operating under harsh Himalayan/Terai sunlight.
class NepalGovTheme {
  const NepalGovTheme._();

  static const Color warmStoneBackground = Color(0xFFECEAE4);
  static const Color elevatedPaper = Color(0xFFF7F5F0);
  static const Color darkSlateCard = Color(0xFF0F172A);
  static const Color slateSecondary = Color(0xFF1E293B);
  static const Color mutedInk = Color(0xFF475569);
  static const Color borderStone = Color(0xFFD6D3C9);

  static const Color outbreakCrimson = Color(0xFFDC2626);
  static const Color containedEmerald = Color(0xFF10B981);
  static const Color monsoonAmber = Color(0xFFD97706);
  static const Color royalNepalBlue = Color(0xFF1D4ED8);

  /// Standard Government of Nepal Unicode Devanagari font fallback stack.
  static const List<String> devanagariFontFallback = <String>[
    'Noto Sans Devanagari',
    'Kalimati',
    'Mangal',
    'Kohinoor Devanagari',
    'sans-serif',
  ];

  /// Minimum interactive touch target dimension (48dp WCAG AAA / Older FCHV Accessibility).
  static const double minTouchTargetDp = 48.0;

  static ThemeData buildTheme({bool highSunlightContrast = false}) {
    final bg = highSunlightContrast ? Colors.white : warmStoneBackground;
    final cardSurface = highSunlightContrast ? Colors.white : elevatedPaper;

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: darkSlateCard,
      onPrimary: Colors.white,
      secondary: outbreakCrimson,
      onSecondary: Colors.white,
      error: outbreakCrimson,
      onError: Colors.white,
      surface: elevatedPaper,
      onSurface: darkSlateCard,
    );

    const baseTextStyle = TextStyle(
      fontFamilyFallback: devanagariFontFallback,
      height: 1.45,
      color: darkSlateCard,
    );

    return ThemeData(
      useMaterial3: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontFamilyFallback: devanagariFontFallback,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: darkSlateCard,
        ),
        titleMedium: TextStyle(
          fontFamilyFallback: devanagariFontFallback,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          height: 1.42,
          color: darkSlateCard,
        ),
        bodyLarge: baseTextStyle,
        bodyMedium: baseTextStyle,
        labelLarge: TextStyle(
          fontFamilyFallback: devanagariFontFallback,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: darkSlateCard,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamilyFallback: devanagariFontFallback,
          color: darkSlateCard,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.35,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: highSunlightContrast ? darkSlateCard : borderStone,
            width: highSunlightContrast ? 1.5 : 1.0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        constraints: const BoxConstraints(minHeight: minTouchTargetDp),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderStone),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderStone),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkSlateCard, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkSlateCard,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(minTouchTargetDp, minTouchTargetDp),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamilyFallback: devanagariFontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            height: 1.35,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(minTouchTargetDp, minTouchTargetDp),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(minTouchTargetDp, minTouchTargetDp),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTargetDp, minTouchTargetDp),
        ),
      ),
    );
  }

  static TextStyle monoTelemetry({
    double fontSize = 13,
    Color color = darkSlateCard,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: devanagariFontFallback,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: -0.2,
      height: 1.35,
    );
  }
}
