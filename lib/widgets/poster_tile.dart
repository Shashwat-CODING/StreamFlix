import 'package:flutter/cupertino.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../services/library_service.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';

class PosterTile extends StatelessWidget {
  const PosterTile({super.key, required this.item, required this.onTap});
  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: AppTheme.brutalistDecoration(
                context: context,
                color: isDark ? AppTheme.darkSlate : CupertinoColors.white,
                borderRadius: 12.0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: item.posterPath != null
                            ? Image.network(
                                'https://image.tmdb.org/t/p/w500${item.posterPath}',
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(
                                  FluentIcons.movies_and_tv_24_regular,
                                  color: CupertinoColors.systemGrey,
                                  size: 32,
                                ),
                              ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: _WatchLaterButton(item: item),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.mediaType.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              color: CupertinoColors.systemGrey,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchLaterButton extends StatefulWidget {
  const _WatchLaterButton({required this.item});
  final MediaItem item;

  @override
  State<_WatchLaterButton> createState() => _WatchLaterButtonState();
}

class _WatchLaterButtonState extends State<_WatchLaterButton> {
  @override
  Widget build(BuildContext context) {
    final isSaved = LibraryService.instance.isInWatchLater(widget.item);
    return GestureDetector(
      onTap: () {
        if (isSaved) {
          LibraryService.instance.removeFromWatchLater(widget.item);
        } else {
          LibraryService.instance.addToWatchLater(widget.item);
        }
        setState(() {});
      },
      child: ClipOval(
        child: Container(
          color: isSaved 
              ? AppTheme.neonYellow 
              : CupertinoColors.black.withOpacity(0.5),
          padding: const EdgeInsets.all(6.0),
          child: Icon(
            isSaved ? FluentIcons.checkmark_24_filled : FluentIcons.add_24_regular,
            size: 14,
            color: CupertinoColors.white,
          ),
        ),
      ),
    );
  }
}
