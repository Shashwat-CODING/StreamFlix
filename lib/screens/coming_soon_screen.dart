import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
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
                        color: cs.primary.withOpacity(
                          0.1 + _pulseController.value * 0.2,
                        ),
                        blurRadius: 40 + _pulseController.value * 30,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(
                      color: cs.primary.withAlpha(
                        (40 + _pulseController.value * 60).toInt(),
                      ),
                      width: 2,
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: child,
                  ),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.sparkles,
                    color: cs.primary,
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
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Coming\n',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'Soon',
                          style: TextStyle(color: cs.primary),
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
                  color: cs.onSurfaceVariant,
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 48),

              FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.arrow_left, size: 18),
                    label: const Text('Go Back'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
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
