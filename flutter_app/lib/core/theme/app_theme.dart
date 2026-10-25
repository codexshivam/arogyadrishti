import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Spacing & semantic tokens used across clinical screens.
class NidanIQSpacing {
  NidanIQSpacing._();

  static const double cardRadius = 12.0;
  static const Color primary = NidanIQTheme.primaryCrimson;
  static const Color surfaceLowest = NidanIQTheme.surfaceWhite;
  static const Color surfaceLow = NidanIQTheme.surfaceContainerLow;
  static const Color onSurface = NidanIQTheme.slateHeading;
  static const Color onSurfaceVariant = NidanIQTheme.slateMuted;
  static const Color outlineVariant = NidanIQTheme.borderHairline;
  static const Color riskCritical = Color(0xFFBA1A1A);
  static const Color riskModerate = Color(0xFFD97706);
  static const Color riskSafe = Color(0xFF16A34A);
}

/// Design tokens and Material 3 theme strictly implementing DESIGN.md ("NidanIQ").
class NidanIQTheme {
  NidanIQTheme._();

  static const List<BoxShadow> ambientElevation = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 16, offset: Offset(0, 6)),
  ];

  // --- Core Palette (DESIGN.md) ---
  static const SystemUiOverlayStyle whiteSystemUiOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.white,
  );

  static const Color primaryCrimson = Color(0xFFA50C1F);
  static const Color primaryCrimsonDark = Color(0xFF7C0012);
  static const Color primaryCrimsonActive = Color(0xFF991B1B);
  static const Color backgroundCanvas = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color borderHairline = Color(0xFFE2E8F0);
  static const Color inputBorder = Color(0xFFCBD5E1);

  // --- Slate Text Scale ---
  static const Color slateHeading = Color(0xFF0F172A);
  static const Color slateBody = Color(0xFF334155);
  static const Color slateMuted = Color(0xFF64748B);

  // --- Triage Badge Palette ---
  static const Color triageRedBg = Color(0xFFFEE2E2);
  static const Color triageRedText = Color(0xFF991B1B);
  static const Color triageAmberBg = Color(0xFFFEF3C7);
  static const Color triageAmberText = Color(0xFF92400E);
  static const Color triageEmeraldBg = Color(0xFFDCFCE7);
  static const Color triageEmeraldText = Color(0xFF166534);
  static const Color aiChipBg = Color(0xFFE0E7FF);
  static const Color aiChipText = Color(0xFF4338CA);

  // --- AI Accent Gradient ---
  static const LinearGradient aiSparkGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFFC084FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient crimsonHeaderGradient = LinearGradient(
    colors: [Color(0xFFA50C1F), Color(0xFF7C0012)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData lightTheme() {
    final baseText = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: whiteSystemUiOverlay,
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryCrimson,
        onPrimary: surfaceWhite,
        primaryContainer: primaryCrimsonDark,
        onPrimaryContainer: Color(0xFFFFB1AD),
        secondary: Color(0xFF565E74),
        onSecondary: surfaceWhite,
        tertiary: Color(0xFF201BB3),
        surface: surfaceWhite,
        onSurface: slateHeading,
        error: Color(0xFFBA1A1A),
      ),
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: slateHeading,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: slateHeading,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: slateHeading,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: slateHeading,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: slateBody,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          color: slateBody,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: slateHeading,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: slateMuted,
          letterSpacing: 0.6,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderHairline, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCrimson,
          foregroundColor: surfaceWhite,
          minimumSize: const Size(64, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surfaceWhite,
          foregroundColor: slateHeading,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: inputBorder, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryCrimson, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}
