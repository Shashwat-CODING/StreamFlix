import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';

class HeroBanner extends StatefulWidget {
  final List<MediaItem> items;
  final Function(MediaItem) onTap;

  const HeroBanner({super.key, required this.items, required this.onTap});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  final PageController _controller = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.items.isEmpty) return;
      final next = (_current + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox(height: 500);
    return SizedBox(
      height: 550,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.items.length,
            itemBuilder: (_, i) => _HeroPage(
              item: widget.items[i],
              onTap: () => widget.onTap(widget.items[i]),
            ),
          ),
          if (widget.items.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.items.length.clamp(0, 10),
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _current ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _current
                          ? AppTheme.neonYellow
                          : CupertinoColors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroPage extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _HeroPage({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop image
        item.fullBackdropUrl.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.fullBackdropUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: CupertinoColors.black),
                    errorWidget: (_, _, _) => Container(color: CupertinoColors.black),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.3, 0.6, 0.8, 1.0],
                        colors: [
                          CupertinoColors.transparent,
                          CupertinoColors.transparent,
                          Color(0x4D000000),
                          Color(0xCC000000),
                          CupertinoColors.black,
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(color: CupertinoColors.black),

        // Content
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Small Poster Image
              if (item.fullPosterUrl.isNotEmpty) ...[
                Container(
                  height: 170,
                  width: 115,
                  decoration: AppTheme.brutalistDecoration(
                    context: context,
                    borderRadius: 12.0,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: CachedNetworkImage(
                      imageUrl: item.fullPosterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: CupertinoColors.systemGrey6),
                      errorWidget: (_, _, _) => const Icon(FluentIcons.image_24_regular),
                    ),
                  ),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 16),
              ],
              // Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.neonYellow,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (item.mediaType == 'tv' ? 'SERIES' : 'FILM').toUpperCase(),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.4,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: CupertinoColors.black,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
              ),
              const SizedBox(height: 12),
              const Text(
                'Exciting • Thriller • Action',
                style: TextStyle(
                  color: AppTheme.neonYellow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _VerticalIconButton(
                    icon: FluentIcons.add_24_regular,
                    label: 'MY LIST',
                    onTap: () {},
                  ),
                  _HeroPlayButton(onTap: () => onTap()),
                  _VerticalIconButton(
                    icon: FluentIcons.info_24_regular,
                    label: 'INFO',
                    onTap: () => onTap(),
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15, end: 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerticalIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _VerticalIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: CupertinoColors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroPlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.25),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.play_20_filled, color: CupertinoColors.black, size: 18),
            SizedBox(width: 8),
            Text(
              'Play Now',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.black,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
