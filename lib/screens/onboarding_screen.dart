import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/deeplink_service.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Solid deep black
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // Logo
              Image.asset(
                'assets/logo.png',
                width: 100,
                height: 100,
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 32),

              Text(
                'Drishya',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 42,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

              const SizedBox(height: 12),

              Text(
                'Cinematic Excellence. Everywhere.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

              const Spacer(flex: 1),

              // Setup Guide
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.settings, color: Color(0xFFE50914), size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Initial Configuration',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This application requires a backend server to function. Please link your instance to synchronize your library and streaming sources.',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 20),

              // Disclaimer/About
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(CupertinoIcons.info_circle_fill, color: Colors.amber, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Disclaimer: Drishya is an aggregator. We do not host, store, or distribute any copyrighted media. All content is fetched live from third-party community-driven APIs.',
                        style: GoogleFonts.dmSans(
                          color: Colors.amber.withValues(alpha: 0.8),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms),

              const Spacer(flex: 2),

              // Action Button
              GestureDetector(
                onTap: () => _launchConfig(),
                child: Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Open Setup Portal',
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _launchConfig() async {
    final url = Uri.parse('${ApiService.websiteUrl}/config');
    // Force external application (browser) to avoid deep-link hijacking loops
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
      width: size, height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
