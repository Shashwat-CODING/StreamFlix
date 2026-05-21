import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/song_model.dart';
import '../services/music_service.dart';
import '../services/collection_service.dart';
import 'music_player_screen.dart';
import '../widgets/ios_widgets.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SongModel> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _performSearch('trending hindi songs');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await MusicService.instance.searchSongs(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
          if (results.isEmpty) _error = 'No songs found for "$query"';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Something went wrong. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: const Text('Music'),
            backgroundColor: isDark ? const Color(0xCC000000) : const Color(0xCCF2F2F7),
            border: null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: IOSSearchField(
                controller: _searchController,
                onSubmitted: _performSearch,
                placeholder: 'Songs, Artists, Albums...',
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: IOSLoading(message: 'Searching for your tunes...')),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.music_note_2, size: 64, color: CupertinoColors.systemGrey4),
                    const SizedBox(height: 16),
                    Text(_error!, style: GoogleFonts.outfit(color: CupertinoColors.systemGrey, fontSize: 16), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _searchResults[index];
                    return _SongTile(song: song, index: index)
                      .animate()
                      .fadeIn(delay: (index * 20).ms);
                  },
                  childCount: _searchResults.length,
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final SongModel song;
  final int index;

  const _SongTile({required this.song, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: MusicService.instance,
      builder: (context, _) {
        final isCurrent = MusicService.instance.currentSong?.id == song.id;

        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            if (isCurrent) {
              MusicService.instance.togglePlayPause();
            } else {
              MusicService.instance.playSong(song);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isCurrent ? theme.primaryColor.withValues(alpha: 0.1) : const Color(0x00000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: song.imageUrl ?? '',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(width: 52, height: 52, color: CupertinoColors.black.withValues(alpha: 0.12), child: const Icon(CupertinoIcons.music_note)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.name,
                        style: GoogleFonts.outfit(
                          color: isCurrent ? theme.primaryColor : (isDark ? CupertinoColors.white : CupertinoColors.black),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artistName,
                        style: GoogleFonts.outfit(color: CupertinoColors.systemGrey, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Icon(CupertinoIcons.speaker_3_fill, color: theme.primaryColor, size: 16)
                else
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showSongOptions(context, song),
                    child: const Icon(CupertinoIcons.ellipsis, size: 20, color: CupertinoColors.systemGrey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSongOptions(BuildContext context, SongModel song) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(song.name),
        message: Text(song.artistName),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              MusicService.instance.playSong(song);
            },
            child: const Text('Play Now'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              MusicService.instance.playNext(song);
            },
            child: const Text('Play Next'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              MusicService.instance.addToQueue(song);
            },
            child: const Text('Add to Queue'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showPlaylistPicker(context, song);
            },
            child: const Text('Add to Playlist'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showPlaylistPicker(BuildContext context, SongModel song) {
    final playlists = CollectionService.instance.playlists;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add to Playlist'),
        actions: playlists.map((p) => CupertinoActionSheetAction(
          onPressed: () {
            CollectionService.instance.addSongToPlaylist(p.id, song);
            Navigator.pop(context);
          },
          child: Text(p.name),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
