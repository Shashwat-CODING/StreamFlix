import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../services/watch_history.dart';
import '../services/bookmark_service.dart';
import '../services/api_service.dart';
import '../services/streaming_service.dart';
import '../models/download_item.dart';
import 'dart:async';

import 'detail_screen.dart';
import 'player_screen.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';

class LibraryScreen extends StatefulWidget {
  final VoidCallback onSearch;
  const LibraryScreen({super.key, required this.onSearch});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _api = ApiService.instance;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: ValueListenableBuilder<int>(
        valueListenable: StreamingService.listChanged,
        builder: (context, _, _) => ValueListenableBuilder<int>(
          valueListenable: BookmarkService.listChanged,
          builder: (context, _, _) => ValueListenableBuilder<int>(
            valueListenable: WatchHistory.listChanged,
            builder: (context, _, _) {
              // Re-categorize Bookmarks dynamically
              final bookmarkedMovies = BookmarkService.bookmarks
                  .where((m) => m.mediaType == 'movie')
                  .toList();
              final bookmarkedTv = BookmarkService.bookmarks
                  .where((m) => m.mediaType == 'tv')
                  .toList();
            final historyMovies = WatchHistory.history
                .where((m) => m.mediaType == 'movie')
                .toList();
            final historyTv = WatchHistory.history
                .where((m) => m.mediaType == 'tv')
                .toList();
            final downloads = StreamingService.instance.downloads;
            final isEmpty =
                downloads.isEmpty &&
                bookmarkedMovies.isEmpty &&
                bookmarkedTv.isEmpty &&
                historyMovies.isEmpty &&
                historyTv.isEmpty;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(cs),

                    if (isEmpty)
                      _buildEmptyState(cs)
                    else ...[
                      if (downloads.isNotEmpty)
                        _buildSectionHeader(
                          'Downloads',
                          downloads.length,
                          cs,
                        ),
                      if (downloads.isNotEmpty)
                        _buildDownloadsList(downloads, cs),
                      
                      if (downloads.isNotEmpty)
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // My List Categories
                      if (bookmarkedMovies.isNotEmpty)
                        _buildSectionHeader(
                          'My List - Movies',
                          bookmarkedMovies.length,
                          cs,
                        ),
                      if (bookmarkedMovies.isNotEmpty)
                        _buildHorizontalList(bookmarkedMovies, cs),

                      if (bookmarkedTv.isNotEmpty)
                        _buildSectionHeader(
                          'My List - TV Series',
                          bookmarkedTv.length,
                          cs,
                        ),
                      if (bookmarkedTv.isNotEmpty)
                        _buildHorizontalList(bookmarkedTv, cs),

                      // Spacing if history exists
                      if (historyMovies.isNotEmpty || historyTv.isNotEmpty)
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // History Categories
                      if (historyMovies.isNotEmpty)
                        _buildSectionHeader(
                          'Continue Watching - Movies',
                          historyMovies.length,
                          cs,
                        ),
                      if (historyMovies.isNotEmpty)
                        _buildHorizontalList(historyMovies, cs),

                      if (historyTv.isNotEmpty)
                        _buildSectionHeader(
                          'Continue Watching - TV Series',
                          historyTv.length,
                          cs,
                        ),
                      if (historyTv.isNotEmpty) _buildHorizontalList(historyTv, cs),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                          child: Column(
                            children: [
                              const Center(child: NativeAdWidget()),
                              const SizedBox(height: 32),
                              const NativeAdWidget(size: NativeAdSize.small),
                              const SizedBox(height: 32),
                              BannerAdWidget(),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ));
  }

  Widget _buildAppBar(ColorScheme cs) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Image.asset('assets/logo.png', width: 24, height: 24).animate().fadeIn(duration: 400.ms),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: 'My ',
                  style: TextStyle(color: cs.onSurface),
                ),
                TextSpan(
                  text: 'Library',
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(CupertinoIcons.search, color: cs.onSurface, size: 22),
          onPressed: widget.onSearch,
        ),
        const SizedBox(width: 8),
      ],
    );
  }



  Widget _buildSectionHeader(String title, int count, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              title,
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 20,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '($count)',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalList(List<MediaItem> items, ColorScheme cs) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.crossAxisExtent >= 700;

        if (isDesktop) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate((_, i) {
                final item = items[i];
                return _LibraryCard(
                  item: item,
                  onTap: () async {
                    final detail = item.mediaType == 'movie'
                        ? await _api.getMovieDetail(item.id)
                        : await _api.getTvDetail(item.id);
                    if (detail != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(item: detail),
                        ),
                      ).then((_) => setState(() {}));
                    }
                  },
                );
              }, childCount: items.length),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: SizedBox(
            height: 190,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = items[index];
                return _LibraryCard(
                  item: item,
                  onTap: () async {
                    final detail = item.mediaType == 'movie'
                        ? await _api.getMovieDetail(item.id)
                        : await _api.getTvDetail(item.id);
                    if (detail != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(item: detail),
                        ),
                      ).then((_) => setState(() {}));
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.square_stack_3d_down_right,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Your library is empty',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Songs and movies you save or watch\nwill appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ).animate().fadeIn(),
      ),
    );
  }

  Widget _buildDownloadsList(List<DownloadItem> items, ColorScheme cs) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          final mi = item.mediaItem;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: mi.fullPosterUrl,
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        width: 60, height: 90, color: cs.surfaceContainerHighest,
                        child: Icon(CupertinoIcons.film, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mi.title,
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              item.status.name.toUpperCase(),
                              style: GoogleFonts.dmSans(
                                color: item.status == DownloadStatus.failed ? Colors.red : 
                                      (item.status == DownloadStatus.completed ? Colors.green : cs.primary),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (item.sourceLabel != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  item.sourceLabel!,
                                  style: GoogleFonts.dmSans(
                                    color: cs.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (item.status == DownloadStatus.downloading || item.status == DownloadStatus.paused) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: item.progress,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(item.progress * 100).toInt()}%',
                                style: GoogleFonts.dmSans(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.status == DownloadStatus.downloading)
                        IconButton(
                          icon: const Icon(CupertinoIcons.pause_fill),
                          onPressed: () {
                            StreamingService.instance.pauseDownload(item.id);
                            setState(() {});
                          },
                        ),
                      if (item.status == DownloadStatus.paused || item.status == DownloadStatus.failed)
                        IconButton(
                          icon: Icon(item.status == DownloadStatus.failed ? CupertinoIcons.refresh_circled_solid : CupertinoIcons.play_fill),
                          color: item.status == DownloadStatus.failed ? Colors.red : null,
                          onPressed: () {
                            StreamingService.instance.resumeDownload(item.id);
                            setState(() {});
                          },
                        ),
                      if (item.status == DownloadStatus.completed)
                        IconButton(
                          icon: const Icon(CupertinoIcons.play_circle_fill, size: 32),
                          color: cs.primary,
                          onPressed: () {
                            // Offline Playback using existing PlayerScreen
                            // PlayerScreen needs to be able to accept a local URL, but actually `media_kit` plays `file://` urls seamlessly!
                            // Since PlayerScreen relies on TMDB ID to fetch streams from Drishya backend, 
                            // we need a minor bypass in PlayerScreen if user wants to play local file directly.
                            _playDownloadedFile(item);
                          },
                        ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                        onPressed: () {
                          StreamingService.instance.cancelDownload(item.id);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        childCount: items.length,
      ),
    );
  }

  void _playDownloadedFile(DownloadItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          item: item.mediaItem,
          offlinePath: 'file:///${item.savedPath}',
        ),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _LibraryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child:
          Container(
                width: 124,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: cs.surfaceContainerHigh,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Poster
                    item.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: item.fullPosterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: cs.surfaceContainerHigh),
                          )
                        : Container(
                            color: cs.surfaceContainerHigh,
                            child: Icon(
                              CupertinoIcons.film,
                              color: cs.onSurfaceVariant,
                            ),
                          ),

                    // Subtle Gradient Overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.6, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),

                    if (item.extraInfo != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.extraInfo!,
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Info (Optional: Progress or simplified title)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            const Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),

                    // Hover/Tap effect
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onTap,
                          splashColor: cs.primary.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(
                begin: const Offset(0.95, 0.95),
                curve: Curves.easeOutBack,
              ),
    );
  }
}



