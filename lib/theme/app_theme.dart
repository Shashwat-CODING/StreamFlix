import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Apple Liquid Glass + Samsung TV-inspired design — Red accent
class AppTheme {
  // ── Red accent palette ──────────────────────────────────────────────────────
  static const Color _accentRed = Color(0xFFE50914); // Proper bold red
  static const Color _accentRedDim = Color(0xFFE50914);
  static const Color _darkBg = Color(
    0xFF000000,
  ); // True OLED Black for iOS feel
  static const Color _darkSurface = Color(0xFF000000);
  static const Color _darkCard = Color(0xFF1C1C1E); // iOS System dark gray
  static const Color _darkCardHigh = Color(0xFF2C2C2E); // iOS elevated gray

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _accentRed,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFD9E2),
      onPrimaryContainer: Color(0xFF3E0010),
      secondary: Color(0xFFC83B61),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFD6E0),
      onSecondaryContainer: Color(0xFF3E0016),
      tertiary: Color(0xFFFF8C42),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFDBC9),
      onTertiaryContainer: Color(0xFF2B1200),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFBFBFD),
      onSurface: Color(0xFF1C1C1E),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF7F7F7),
      surfaceContainer: Color(0xFFF2F2F7),
      surfaceContainerHigh: Color(0xFFEBEBF0),
      surfaceContainerHighest: Color(0xFFE5E5EA),
      onSurfaceVariant: Color(0xFF444446),
      outline: Color(0xFF8E8E93),
      outlineVariant: Color(0xFFD1D1D6),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF1C1C1E),
      onInverseSurface: Color(0xFFFBFBFD),
      inversePrimary: Color(0xFFFFB1C8),
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _accentRedDim,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF4A0F1E),
      onPrimaryContainer: Color(0xFFFFD9E2),
      secondary: Color(0xFFDE7B9C),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF4A1A2A),
      onSecondaryContainer: Color(0xFFFFD6E0),
      tertiary: Color(0xFFFF8C42),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF3D1800),
      onTertiaryContainer: Color(0xFFFFDBC9),
      error: Color(0xFFFF6B6B),
      onError: Colors.white,
      errorContainer: Color(0xFF3D0000),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: _darkBg,
      onSurface: Color(0xFFF0F0FF),
      surfaceContainerLowest: Color(0xFF0D0D17),
      surfaceContainerLow: Color(0xFF12121B),
      surfaceContainer: _darkSurface,
      surfaceContainerHigh: _darkCard,
      surfaceContainerHighest: _darkCardHigh,
      onSurfaceVariant: Color(0xFFA8A8C0),
      outline: Color(0xFF35354A),
      outlineVariant: Color(0xFF252535),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFF0F0FF),
      onInverseSurface: Color(0xFF0A0A0F),
      inversePrimary: _accentRed,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: cs.brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      splashFactory: InkRipple.splashFactory,
      textTheme: GoogleFonts.dmSansTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSerifDisplay(
          color: cs.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(color: cs.onSurface, size: 24),
      ),
      // Transparent — we use a fully custom nav bar
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1C1C1E) : cs.surface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5)
              : BorderSide(color: Colors.black.withOpacity(0.05), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary.withOpacity(0.4), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        labelStyle: GoogleFonts.dmSans(
          color: cs.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withOpacity(0.6),
          letterSpacing: 0,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF252535) : cs.inverseSurface,
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFF0F0FF) : cs.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF14141C) : cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withOpacity(0.4),
        thickness: 0.5,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _accentRedDim,
        linearTrackColor: cs.surfaceContainerHighest,
      ),
    );
  }
}
