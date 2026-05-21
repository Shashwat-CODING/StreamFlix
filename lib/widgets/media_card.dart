import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/media_item.dart';
import 'shimmer_placeholder.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const MediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.width = 120,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Poster Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.fullPosterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.fullPosterUrl,
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        ShimmerPlaceholder(width: width, height: height),
                    errorWidget: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),

          // Bottom Gradient Overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 1.0],
                    colors: [CupertinoColors.transparent, CupertinoColors.black.withValues(alpha: 0.9)],
                  ),
                ),
              ),
            ),
          ),

          // Overlay Content
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.voteAverage > 0) ...[
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.star_fill,
                        color: Color(0xFFFFC107),
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.ratingStr,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  item.title,
                  style: GoogleFonts.outfit(
                    color: CupertinoColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1C1C1E),
      child: const Icon(CupertinoIcons.film, color: Color(0x3DFFFFFF), size: 32),
    );
  }
}

class CategoryRow extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final Function(MediaItem) onTap;
  final bool isLoading;

  const CategoryRow({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: onSurface,
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_forward,
                color: CupertinoColors.systemGrey,
                size: 16,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: isLoading
              ? _buildLoadingRow()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      MediaCard(item: items[i], onTap: () => onTap(items[i])),
                ),
        ),
      ],
    );
  }

  Widget _buildLoadingRow() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => const ShimmerPlaceholder(width: 120, height: 180),
    );
  }
}

