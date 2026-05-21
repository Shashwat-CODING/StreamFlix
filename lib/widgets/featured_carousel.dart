import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/media_item.dart';

class FeaturedCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final Function(MediaItem) onTap;

  const FeaturedCarousel({super.key, required this.items, required this.onTap});

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  late PageController _controller;
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.85);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.items.isEmpty) return;
      final next = (_current + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 800),
        curve: Curves.fastOutSlowIn,
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
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 480,
      child: PageView.builder(
        controller: _controller,
        onPageChanged: (i) => setState(() => _current = i),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final isSelection = index == _current;
          return AnimatedScale(
            scale: isSelection ? 1.0 : 0.9,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: _CarouselCard(
              item: widget.items[index],
              isActive: isSelection,
              onTap: () => widget.onTap(widget.items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  final MediaItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _CarouselCard({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ]
              : [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop image
              item.fullPosterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.fullPosterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                      ),
                    )
                  : Container(
                      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                    ),

              // Gradient Overlay
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.4, 0.7, 1.0],
                    colors: [
                      CupertinoColors.transparent,
                      Color(0x1A000000),
                      Color(0x99000000),
                      Color(0xF2000000),
                    ],
                  ),
                ),
              ),

              // Blur if not active
              if (!isActive)
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(color: CupertinoColors.black.withValues(alpha: 0.3)),
                ),

              // Content Content
              if (isActive)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.star_fill,
                                      color: theme.primaryColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.ratingStr,
                                      style: GoogleFonts.outfit(
                                        color: CupertinoColors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.year,
                                style: GoogleFonts.outfit(
                                  color: CupertinoColors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 12),

                      Text(
                            item.title,
                            style: GoogleFonts.outfit(
                              color: CupertinoColors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 16),

                      Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                  onPressed: onTap,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(CupertinoIcons.play_fill, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Watch Now',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              CupertinoButton(
                                padding: const EdgeInsets.all(12),
                                color: CupertinoColors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                onPressed: () {},
                                child: const Icon(CupertinoIcons.add, size: 24, color: CupertinoColors.white),
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

