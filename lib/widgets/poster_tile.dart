import 'package:flutter/material.dart';
import '../services/tmdb_service.dart';
import '../services/library_service.dart';

class PosterTile extends StatelessWidget {
  const PosterTile({super.key, required this.item, required this.onTap});
  final TmdbItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF2F2F7),
                child: Stack(children: [
                  Positioned.fill(
                    child: item.posterPath != null
                        ? Image.network('https://image.tmdb.org/t/p/w500${item.posterPath}', fit: BoxFit.cover)
                        : Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
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
        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        Text(item.mediaType.toUpperCase(),
            style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6))),
      ]),
    );
  }
}

class _WatchLaterButton extends StatefulWidget {
  const _WatchLaterButton({required this.item});
  final TmdbItem item;

  @override
  State<_WatchLaterButton> createState() => _WatchLaterButtonState();
}

class _WatchLaterButtonState extends State<_WatchLaterButton> {
  @override
  Widget build(BuildContext context) {
    final isSaved = LibraryService.instance.isInWatchLater(widget.item);
    return Material(
      color: Colors.black.withOpacity(0.45),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (isSaved) {
            LibraryService.instance.removeFromWatchLater(widget.item);
          } else {
            LibraryService.instance.addToWatchLater(widget.item);
          }
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(isSaved ? Icons.check : Icons.add, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}


