import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// IOS Liquid Glass Theme System
class AppTheme {
  static const Color accentBlue = CupertinoColors.systemBlue;
  
  static const LinearGradient luxaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF4F0FF), // soft white lavender
      Color(0xFFC9A7FF), // pastel purple
      Color(0xFFFFB3D1), // pink
      Color(0xFFFFBE8C), // peach orange
      Color(0xFFFFEFA3), // soft yellow
    ],
    stops: [0.0, 0.22, 0.48, 0.74, 1.0],
  );
  
  static CupertinoThemeData iosTheme(Brightness? brightness, {String? customFont}) {
    // If brightness is null, we'll let the app handle it, but usually it's passed from main
    final isDark = brightness == Brightness.dark;
    
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: accentBlue,
      primaryContrastingColor: CupertinoColors.white,
      barBackgroundColor: isDark 
          ? const Color(0xB31C1C1E) // Translucent dark
          : const Color(0xB3FFFFFF), // Translucent light
      scaffoldBackgroundColor: isDark 
          ? CupertinoColors.black 
          : const Color(0xFFF2F2F7),
      textTheme: CupertinoTextThemeData(
        primaryColor: accentBlue,
        textStyle: (customFont != null 
                ? (customFont == 'Karst' ? const TextStyle(fontFamily: 'Karst') : GoogleFonts.getFont(customFont)) 
                : GoogleFonts.outfit())
            .copyWith(
          color: isDark ? CupertinoColors.white : CupertinoColors.black,
        ),
      ),
    );
  }

  // Glassmorphic Decoration Utility
  static BoxDecoration glassDecoration({
    required BuildContext context,
    double opacity = 0.7,
    double blur = 20,
    double borderRadius = 12,
  }) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return BoxDecoration(
      color: (isDark ? CupertinoColors.black : CupertinoColors.white).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: (isDark ? CupertinoColors.white : CupertinoColors.black).withValues(alpha: 0.1),
        width: 0.5,
      ),
    );
  }
}
