import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator, AlwaysStoppedAnimation, Material, MaterialType;
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

extension CupertinoThemeDataX on CupertinoThemeData {
  CupertinoColorScheme get colorScheme => CupertinoColorScheme(this);
}

class CupertinoColorScheme {
  final CupertinoThemeData _theme;
  CupertinoColorScheme(this._theme);

  CupertinoThemeData get theme => _theme;

  Color get primary => _theme.primaryColor;
  Color get onPrimary => CupertinoColors.white;
  Color get onSurface => _theme.brightness == Brightness.dark ? CupertinoColors.white : CupertinoColors.black;
  Color get onSurfaceVariant => _theme.brightness == Brightness.dark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2;
  Color get surface => _theme.brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  Color get surfaceContainerHigh => _theme.brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  Color get surfaceContainerHighest => _theme.brightness == Brightness.dark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6);
  Color get surfaceContainerLowest => _theme.brightness == Brightness.dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  Color get outlineVariant => _theme.brightness == Brightness.dark ? CupertinoColors.systemGrey4 : CupertinoColors.systemGrey5;
  Color get primaryContainer => _theme.primaryColor.withValues(alpha: 0.2);
  Color get error => CupertinoColors.systemRed;
  Color get onErrorContainer => CupertinoColors.white;
  Color get errorContainer => CupertinoColors.systemRed.withValues(alpha: 0.2);
  
  Color get onSecondaryContainer => onSurfaceVariant;
  Color get secondaryContainer => _theme.brightness == Brightness.dark
      ? const Color(0x33FFFFFF)
      : const Color(0x1A000000);
  Color get shadow => CupertinoColors.black;
}

class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const GlassBox({
    super.key,
    required this.child,
    this.blur = 30.0,
    this.opacity = 0.2,
    this.borderRadius = 16.0,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? (isDark 
                ? CupertinoColors.white.withValues(alpha: opacity * 0.5) 
                : CupertinoColors.black.withValues(alpha: opacity * 0.1)),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: (isDark ? CupertinoColors.white : CupertinoColors.black).withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class IOSSearchField extends StatelessWidget {
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final TextEditingController? controller;

  const IOSSearchField({
    super.key,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoSearchTextField(
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        backgroundColor: isDark 
            ? CupertinoColors.systemGrey6.darkColor.withValues(alpha: 0.5)
            : CupertinoColors.systemGrey6.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        style: GoogleFonts.outfit(
          color: isDark ? CupertinoColors.white : CupertinoColors.black,
        ),
        placeholderStyle: GoogleFonts.outfit(
          color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
        ),
      ),
    );
  }
}

class IOSSettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const IOSSettingsGroup({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, top: 24),
            child: Text(
              title!.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: CupertinoTheme.of(context).barBackgroundColor.withValues(alpha: 1.0),
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: List.generate(children.length, (index) {
              return Column(
                children: [
                  children[index],
                  if (index < children.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Container(height: 0.5, color: CupertinoColors.separator),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class IOSSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const IOSSettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: CupertinoColors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
                      fontSize: 17,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: GoogleFonts.outfit(
                        color: CupertinoColors.systemGrey,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing! else const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.systemGrey3, size: 20),
          ],
        ),
      ),
    );
  }
}

class IOSSettingsSwitch extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const IOSSettingsSwitch({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: CupertinoColors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                fontSize: 17,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: CupertinoColors.systemGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class IOSLoading extends StatelessWidget {
  final String? message;
  final double size;
  const IOSLoading({super.key, this.message, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Material(
                      type: MaterialType.transparency,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CupertinoTheme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    CupertinoIcons.play_fill,
                    size: size * 0.4,
                    color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class IOSLoadingOverlay extends StatelessWidget {
  final String? message;
  const IOSLoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.black.withValues(alpha: 0.4),
      child: Center(
        child: IOSLoading(message: message, size: 48),
      ),
    );
  }
}

class ConstrainedBottomSheet extends StatelessWidget {
  final Widget child;
  const ConstrainedBottomSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: size.height * 0.75,
        ),
        child: child,
      ),
    );
  }
}
