import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
    
    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Dynamic Background Blobs
          Positioned(
            top: -100,
            right: -50,
            child: _AmbientBlob(
              color: const Color(0xFFC9A7FF).withValues(alpha: 0.15),
              size: 300,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _AmbientBlob(
              color: const Color(0xFFFFB3D1).withValues(alpha: 0.15),
              size: 250,
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  
                  // Logo Section
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: AppTheme.luxaGradient.begin,
                          end: AppTheme.luxaGradient.end,
                          colors: AppTheme.luxaGradient.colors.map((c) => c.withValues(alpha: 0.15)).toList(),
                          stops: AppTheme.luxaGradient.stops,
                        ),
                        border: Border.all(color: onSurface.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: onSurface.withValues(alpha: 0.05),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ).animate().scale(duration: 1000.ms, curve: Curves.easeOutBack).fadeIn(),

                  const SizedBox(height: 40),

                  // Brand Name
                  ShaderMask(
                    shaderCallback: (bounds) => AppTheme.luxaGradient.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: Text(
                      'Luxa',
                      style: GoogleFonts.outfit(
                        fontSize: 64,
                        color: CupertinoColors.white,
                        letterSpacing: -2.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOut),

                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'Experience the Future of Streaming',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                  const Spacer(flex: 2),

                  // Feature Cards / Setup Guide (Glassmorphic)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: onSurface.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: onSurface.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            _buildFeatureRow(
                              FluentIcons.flash_24_filled,
                              const Color(0xFFC9A7FF),
                              'Ultra Fast Streaming',
                              'Experience lag-free 4K content globally.',
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Container(height: 1, color: CupertinoColors.systemGrey5.withValues(alpha: 0.2)),
                            ),
                            _buildFeatureRow(
                              FluentIcons.link_24_regular,
                              CupertinoColors.systemBlue,
                              'Instance Configuration',
                              'Link your backend to sync your private library.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),

                  const Spacer(flex: 2),

                  // Action Button
                  CupertinoButton(
                    onPressed: () => _launchConfig(),
                    padding: EdgeInsets.zero,
                    child: Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get Started',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(FluentIcons.arrow_right_24_regular, color: CupertinoColors.white, size: 20),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5),

                  const SizedBox(height: 24),
                  
                  // Footer Info
                  Text(
                    'By continuing, you agree to our Terms of Service.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: onSurface.withValues(alpha: 0.3),
                    ),
                  ).animate().fadeIn(delay: 1000.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, Color color, String title, String subtitle) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  color: onSurface.withValues(alpha: 0.4),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _launchConfig() async {
    final url = Uri.parse('${ApiService.websiteUrl}/config');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _AmbientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: CupertinoColors.transparent),
      ),
    );
  }
}




