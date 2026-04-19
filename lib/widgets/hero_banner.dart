import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/media_item.dart';

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
                    width: i == _current ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _current
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
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
                    placeholder: (_, _) => Container(color: Colors.black),
                    errorWidget: (_, _, _) => Container(color: Colors.black),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.8),
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(color: Colors.black),

        // Content
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.mediaType == 'tv' ? 'S E R I E S' : 'F I L M',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    shadows: [Shadow(blurRadius: 20, color: Colors.black)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
              ),
              const SizedBox(height: 12),
              const Text(
                'Exciting • Thriller • Action',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _VerticalIconButton(
                    icon: Icons.add,
                    label: 'My List',
                    onTap: () {},
                  ),
                  _HeroPlayButton(onTap: () => onTap()),
                  _VerticalIconButton(
                    icon: Icons.info_outline,
                    label: 'Info',
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
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.play_arrow_rounded, size: 24),
      label: const Text(
        'Play Now',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
