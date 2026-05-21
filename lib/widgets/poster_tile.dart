import 'package:flutter/cupertino.dart';
import '../services/library_service.dart';
import '../models/media_item.dart';

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
      child: Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                child: Stack(children: [
                  Positioned.fill(
                    child: item.posterPath != null
                        ? Image.network('https://image.tmdb.org/t/p/w500${item.posterPath}', fit: BoxFit.cover)
                        : const Center(
                            child: Icon(
                              CupertinoIcons.film,
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
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        Text(item.mediaType.toUpperCase(),
            style: TextStyle(fontSize: 10, color: CupertinoColors.systemGrey.withValues(alpha: 0.8))),
      ]),
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
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(6.0),
        child: Icon(isSaved ? CupertinoIcons.check_mark : CupertinoIcons.add, size: 18, color: CupertinoColors.white),
      ),
    );
  }
}



