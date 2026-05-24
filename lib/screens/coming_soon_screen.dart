import 'package:flutter/cupertino.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class ComingSoonScreen extends StatefulWidget {
  final String title;
  const ComingSoonScreen({super.key, required this.title});

  @override
  State<ComingSoonScreen> createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<ComingSoonScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: CupertinoColors.transparent,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(FluentIcons.chevron_left_24_regular),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expressive pulsing indicator
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 
                          0.1 + _pulseController.value * 0.2,
                        ),
                        blurRadius: 40 + _pulseController.value * 30,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(
                      color: primary.withValues(alpha: 0.1 + _pulseController.value * 0.4),
                      width: 2,
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: child,
                  ),
                ),
                child: Center(
                  child: Icon(
                    FluentIcons.sparkle_24_regular,
                    color: primary,
                    size: 40,
                  ),
                ),
              ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),

              const SizedBox(height: 48),

              RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontSize: 42,
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                      children: [
                        TextSpan(
                          text: 'Coming\n',
                          style: TextStyle(color: onSurface),
                        ),
                        TextSpan(
                          text: 'Soon',
                          style: TextStyle(color: primary),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

              const SizedBox(height: 20),

              Text(
                widget.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'We\'re preparing something special.\nStay tuned for the premiere of this content.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: CupertinoColors.systemGrey,
                    height: 1.6,
                    fontSize: 16,
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 48),

              CupertinoButton(
                    color: primary,
                    borderRadius: BorderRadius.circular(16),
                    onPressed: () => Navigator.pop(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.arrow_left_24_regular, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Go Back',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 800.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}



