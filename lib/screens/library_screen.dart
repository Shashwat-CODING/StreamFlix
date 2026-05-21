import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show Listenable;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../models/media_item.dart';
import '../models/song_model.dart';
import '../models/collection_models.dart';
import '../models/download_item.dart';
import '../services/watch_history.dart';
import '../services/music_history.dart';
import '../services/bookmark_service.dart';
import '../services/collection_service.dart';
import '../services/api_service.dart';
import '../services/music_service.dart';
import '../services/watch_history.dart';
import '../services/streaming_service.dart';
import 'detail_screen.dart';
import 'music_player_screen.dart';
import 'player_screen.dart';
import '../widgets/ios_widgets.dart';

class LibraryScreen extends StatefulWidget {
  final VoidCallback onSearch;
  const LibraryScreen({super.key, required this.onSearch});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedSegment = 1;
  final _api = ApiService.instance;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CupertinoPageScaffold(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          WatchHistory.listChanged,
          MusicHistory.listChanged,
          BookmarkService.listChanged,
          CollectionService.instance,
          StreamingService.listChanged,
        ]),
        builder: (context, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              CupertinoSliverNavigationBar(
                transitionBetweenRoutes: false,
                largeTitle: const Text('My Library'),
                backgroundColor: isDark ? const Color(0xCC000000) : const Color(0xCCF2F2F7),
                border: null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: widget.onSearch,
                      child: const Icon(CupertinoIcons.search, size: 24),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _selectedSegment,
                      children: {
                        0: _buildTabText('Watchlist', theme),
                        1: _buildTabText('History', theme),
                        2: _buildTabText('Downloads', theme),
                        3: _buildTabText('Playlists', theme),
                        4: _buildTabText('Collections', theme),
                      },
                      onValueChanged: (val) {
                        if (val != null) setState(() => _selectedSegment = val);
                      },
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
                child: _buildSelectedTab(theme),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectedTab(CupertinoThemeData theme) {
    Widget content;
    switch (_selectedSegment) {
      case 0: content = _buildWatchlistTab(theme); break;
      case 1: content = _buildHistoryTab(theme); break;
      case 2: content = _buildDownloadsTab(theme); break;
      case 3: content = _buildPlaylistsTab(theme); break;
      case 4: content = _buildCollectionsTab(theme); break;
      default: content = const SizedBox.shrink();
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: content,
      ),
    );
  }

  Widget _buildWatchlistTab(CupertinoThemeData theme) {
    final movies = BookmarkService.bookmarks.where((m) => m.mediaType == 'movie').toList();
    final tv = BookmarkService.bookmarks.where((m) => m.mediaType == 'tv' || m.mediaType == 'anime').toList();

    if (movies.isEmpty && tv.isEmpty) return _buildEmptyState('Your watchlist is empty', theme);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (movies.isNotEmpty) ...[
          _buildSubHeader('Movies', movies.length, theme),
          _buildMediaGrid(movies, theme),
          const SizedBox(height: 24),
        ],
        if (tv.isNotEmpty) ...[
          _buildSubHeader('Shows & Anime', tv.length, theme),
          _buildMediaGrid(tv, theme),
        ],
        const SizedBox(height: 140),
      ],
    );
  }

  Widget _buildHistoryTab(CupertinoThemeData theme) {
    final movies = WatchHistory.history.where((m) => m.mediaType == 'movie').toList();
    final seriesProgress = CollectionService.instance.seriesProgress.values.toList()
      ..sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    final musicHistory = MusicHistory.history;

    if (movies.isEmpty && seriesProgress.isEmpty && musicHistory.isEmpty) {
      return _buildEmptyState('No watch history yet', theme);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (seriesProgress.isNotEmpty) ...[
          _buildSubHeader('Series Progress', seriesProgress.length, theme),
          ...seriesProgress.map((s) => _buildSeriesProgressCard(s, theme)),
          const SizedBox(height: 24),
        ],
        if (movies.isNotEmpty) ...[
          _buildSubHeader('Recent Movies', movies.length, theme),
          _buildMediaGrid(movies, theme, isHistory: true),
          const SizedBox(height: 24),
        ],
        if (musicHistory.isNotEmpty) ...[
          _buildSubHeader('Music History', musicHistory.length, theme),
          ...musicHistory.take(10).map((s) => _buildSongTile(s, theme)),
        ],
        const SizedBox(height: 140),
      ],
    );
  }

  Widget _buildDownloadsTab(CupertinoThemeData theme) {
    final downloads = StreamingService.instance.downloads;
    if (downloads.isEmpty) return _buildEmptyState('No downloads found', theme);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final item = downloads[index];
        return _buildDownloadTile(item, theme);
      },
    );
  }

  Widget _buildDownloadTile(DownloadItem item, CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        if (item.status == DownloadStatus.completed) {
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
              builder: (_) => PlayerScreen(
                item: item.mediaItem is MediaDetail ? item.mediaItem as MediaDetail : null,
                offlinePath: item.filePath,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? CupertinoColors.systemGrey6.darkColor : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.mediaItem.fullPosterUrl,
                width: 50,
                height: 75,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: CupertinoColors.black.withValues(alpha: 0.1)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.mediaItem.title,
                    style: theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.status == DownloadStatus.downloading) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        backgroundColor: CupertinoColors.systemGrey4,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(item.progress * 100).toStringAsFixed(1)}% · ${item.speedText ?? ""}',
                      style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                    ),
                  ] else ...[
                    Text(
                      item.status == DownloadStatus.completed ? 'Completed · ${item.sizeText ?? ""}' : 'Failed',
                      style: TextStyle(
                        fontSize: 13,
                        color: item.status == DownloadStatus.completed ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.status == DownloadStatus.completed)
              const Icon(CupertinoIcons.play_circle_fill, color: CupertinoColors.systemGrey2)
            else if (item.status == DownloadStatus.downloading)
              const CupertinoActivityIndicator(radius: 8)
            else
              const Icon(CupertinoIcons.exclamationmark_circle, color: CupertinoColors.systemRed),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsTab(CupertinoThemeData theme) {
    final playlists = CollectionService.instance.playlists;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 260).floor().clamp(2, 6);
    final childAspectRatio = width > 800 ? 1.4 : 1.1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCreateButton('New Playlist', CupertinoIcons.plus_square_fill, theme.primaryColor, () => _showCreatePlaylistDialog(), theme),
        const SizedBox(height: 16),
        if (playlists.isEmpty)
          _buildEmptyState('No playlists created', theme)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) => _buildPlaylistCard(playlists[index], theme),
          ),
        const SizedBox(height: 140),
      ],
    );
  }

  Widget _buildCollectionsTab(CupertinoThemeData theme) {
    final collections = CollectionService.instance.collections;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 260).floor().clamp(2, 6);
    final childAspectRatio = width > 800 ? 1.4 : 1.1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCreateButton('New Collection', CupertinoIcons.folder_badge_plus, theme.primaryColor, () => _showCreateCollectionDialog(), theme),
        const SizedBox(height: 16),
        if (collections.isEmpty)
          _buildEmptyState('No collections created', theme)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: collections.length,
            itemBuilder: (context, index) => _buildCollectionCard(collections[index], theme),
          ),
        const SizedBox(height: 140),
      ],
    );
  }

  Widget _buildSubHeader(String title, int count, CupertinoThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        '$title ($count)',
        style: theme.textTheme.textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMediaGrid(List<MediaItem> items, CupertinoThemeData theme, {bool isHistory = false}) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 180).floor().clamp(3, 8);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, 
        mainAxisSpacing: 12, 
        crossAxisSpacing: 12, 
        childAspectRatio: 2 / 3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _openDetail(item),
          onLongPress: isHistory ? () => _showHistoryItemOptions(item) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item.fullPosterUrl, 
              fit: BoxFit.cover, 
              errorWidget: (_, __, ___) => Container(color: CupertinoColors.black.withValues(alpha: 0.12))
            ),
          ),
        );
      },
    );
  }

  void _showHistoryItemOptions(MediaItem item) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(item.title),
        message: const Text('Would you like to remove this from your history?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              WatchHistory.removeItem(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Remove from History'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildSeriesProgressCard(SeriesProgress progress, CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showSeriesProgressDetail(progress, theme),
      onLongPress: () => _showSeriesProgressOptions(progress),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? CupertinoColors.systemGrey6.darkColor : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(imageUrl: 'https://image.tmdb.org/t/p/w200${progress.posterPath}', width: 50, height: 75, fit: BoxFit.cover),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(progress.title, style: theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('In progress', style: theme.textTheme.textStyle.copyWith(color: theme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    );
  }

  void _showSeriesProgressOptions(SeriesProgress progress) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(progress.title),
        message: const Text('Would you like to remove this series progress?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              CollectionService.instance.removeSeriesProgress(progress.seriesId);
              Navigator.pop(ctx);
            },
            child: const Text('Clear Progress'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildSongTile(SongModel song, CupertinoThemeData theme) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        MusicService.instance.playSong(song);
        Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(builder: (_) => const MusicPlayerScreen()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: song.imageUrl ?? '', width: 50, height: 50, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(song.name, style: theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(song.artistName, style: theme.textTheme.textStyle.copyWith(fontSize: 13, color: CupertinoColors.systemGrey)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(MusicPlaylist playlist, CupertinoThemeData theme) {
    return GlassBox(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.music_note_list, size: 40, color: theme.primaryColor),
          const SizedBox(height: 8),
          Text(playlist.name, style: theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.bold), maxLines: 1),
          Text('${playlist.songs.length} songs', style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(MediaCollection collection, CupertinoThemeData theme) {
    return GlassBox(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.folder_fill, size: 40, color: CupertinoColors.systemBlue),
          const SizedBox(height: 8),
          Text(collection.name, style: theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.bold), maxLines: 1),
          Text('${collection.items.length} items', style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  Widget _buildCreateButton(String label, IconData icon, Color color, VoidCallback onTap, CupertinoThemeData theme) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, CupertinoThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.square_stack_3d_down_right, size: 64, color: CupertinoColors.systemGrey4),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  void _openDetail(MediaItem item) async {
    MediaDetail? detail;
    if (item.mediaType == 'anime') {
      detail = await _api.getAnimeDetail(item);
    } else {
      detail = item.mediaType == 'movie' ? await _api.getMovieDetail(item.id) : await _api.getTvDetail(item.id);
    }
    if (detail != null && mounted) {
      Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(builder: (_) => DetailScreen(item: detail!)));
    }
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Playlist'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(controller: controller, placeholder: 'Playlist Name', autofocus: true),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              if (controller.text.isNotEmpty) {
                CollectionService.instance.createPlaylist(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateCollectionDialog() {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Collection'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(controller: controller, placeholder: 'Collection Name', autofocus: true),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              if (controller.text.isNotEmpty) {
                CollectionService.instance.createCollection(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabText(String text, CupertinoThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Text(
        text,
        style: theme.textTheme.textStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showSeriesProgressDetail(SeriesProgress progress, CupertinoThemeData theme) async {
    final detail = await _api.getTvDetail(progress.seriesId);
    if (detail == null || !mounted) return;
    Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(builder: (_) => DetailScreen(item: detail)));
  }

}

class LinearProgressIndicator extends StatelessWidget {
  final double value;
  final Color backgroundColor;
  final AlwaysStoppedAnimation<Color> valueColor;
  final double minHeight;

  const LinearProgressIndicator({
    super.key,
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
    required this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: minHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(minHeight / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: valueColor.value,
            borderRadius: BorderRadius.circular(minHeight / 2),
          ),
        ),
      ),
    );
  }
}
