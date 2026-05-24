import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// StreamFlix Cupertino Design Theme System
class AppTheme {
  // Cupertino system accents (mapped to keep original variable names but premium iOS color values)
  static const Color neonYellow = Color(0xFF007AFF); // Apple System Blue
  static const Color neonOrange = Color(0xFFFF9500); // Apple System Orange
  static const Color neonPink = Color(0xFFFF2D55);   // Apple System Pink/Red
  static const Color neonBlue = Color(0xFF5AC8FA);   // Apple System Light Blue
  
  // Grayscale colors
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color creamBg = Color(0xFFF2F2F7);    // iOS Light Grouped Background
  static const Color darkSlate = Color(0xFF1C1C1E);   // iOS Dark Grouped Background

  // Smooth Cupertino Gradient Representation
  static const LinearGradient luxaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF007AFF), // iOS Blue
      Color(0xFF5856D6), // iOS Purple
      Color(0xFFFF2D55), // iOS Pink/Red
      Color(0xFF000000), // Pure Black
    ],
    stops: [0.0, 0.33, 0.66, 1.0],
  );
  
  static CupertinoThemeData iosTheme(Brightness? brightness, {String? customFont}) {
    final isDark = brightness == Brightness.dark;
    
    // In premium iOS mode, the primary active color is clean Apple Blue
    final primary = neonYellow;
    final background = isDark ? pureBlack : creamBg;
    final contrast = isDark ? pureBlack : pureWhite;
    final textColor = isDark ? pureWhite : pureBlack;
    
    // Default to Inter for elegant readability
    final baseFont = (customFont != null 
        ? (customFont == 'Karst' ? const TextStyle(fontFamily: 'Karst') : GoogleFonts.getFont(customFont)) 
        : GoogleFonts.inter());
        
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: primary,
      primaryContrastingColor: contrast,
      barBackgroundColor: isDark 
          ? const Color(0xCC1C1C1E) // iOS Translucent Dark Bar
          : const Color(0xCCFFFFFF), // iOS Translucent Light Bar
      scaffoldBackgroundColor: background,
      textTheme: CupertinoTextThemeData(
        primaryColor: primary,
        textStyle: baseFont.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500, // standard, clean weight
        ),
      ),
    );
  }

  /// Global Cupertino Card Decoration Helper
  static BoxDecoration brutalistDecoration({
    required BuildContext context,
    Color? color,
    double borderRadius = 12.0,
    double shadowOffset = 0.0,
    bool hasShadow = true,
    bool hasBorder = true,
    Color? customBorderColor,
  }) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final defaultBg = isDark ? darkSlate : pureWhite;
    
    // Sleek Apple-style border colors: very low opacity, thin
    final borderColor = customBorderColor ?? (isDark ? const Color(0x15FFFFFF) : const Color(0x0D000000));
    
    // Map standard 4px rounded brutalist corners to elegant 12px corners unless custom is specified
    final radius = borderRadius == 4.0 ? 12.0 : borderRadius;

    return BoxDecoration(
      color: color ?? defaultBg,
      borderRadius: BorderRadius.circular(radius),
      border: hasBorder 
          ? Border.all(
              color: borderColor,
              width: 1.0,
            )
          : null,
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: isDark ? const Color(0x3D000000) : const Color(0x08000000),
                offset: const Offset(0, 4),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  /// Refined Glassmorphic Decoration Utility
  static BoxDecoration glassDecoration({
    required BuildContext context,
    double opacity = 0.7,
    double blur = 20,
    double borderRadius = 12,
  }) {
    return brutalistDecoration(
      context: context,
      borderRadius: borderRadius,
    );
  }
}
