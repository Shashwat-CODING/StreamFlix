import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/song_model.dart';
import '../services/music_service.dart';
import '../screens/music_player_screen.dart';

class MiniPlayerWrapper extends StatelessWidget {
  final Widget child;
  const MiniPlayerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        ListenableBuilder(
          listenable: MusicService.instance,
          builder: (context, _) {
            final currentSong = MusicService.instance.currentSong;
            if (currentSong == null) return const SizedBox.shrink();
            return MiniPlayer(song: currentSong);
          },
        ),
      ],
    );
  }
}

class MiniPlayer extends StatelessWidget {
  final SongModel song;
  const MiniPlayer({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;

    final progress = MusicService.instance.duration.inSeconds > 0 
        ? MusicService.instance.position.inSeconds / MusicService.instance.duration.inSeconds 
        : 0.0;

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Container(
      key: const ValueKey('mini_player'),
      decoration: BoxDecoration(
        color: CupertinoColors.transparent,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(
                  builder: (context) => const MusicPlayerScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
            child: Container(
              height: 56 + bottomPadding, 
              padding: EdgeInsets.only(bottom: bottomPadding),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xCC1C1C1E) : const Color(0xCCFFFFFF),
                border: Border(top: BorderSide(color: onSurface.withValues(alpha: 0.1), width: 0.5)),
              ),
              child: Stack(
                children: [
                  // Progress Fill Background (Thin line at top)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1.5,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: song.imageUrl != null
                                ? CachedNetworkImage(imageUrl: song.imageUrl!, width: 40, height: 40, fit: BoxFit.cover)
                                : Container(width: 40, height: 40, color: theme.primaryColor.withValues(alpha: 0.1), child: const Icon(CupertinoIcons.music_note, size: 20)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  song.name, 
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: onSurface, fontSize: 13, letterSpacing: -0.2), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                                Text(
                                  song.artistName, 
                                  style: GoogleFonts.outfit(color: onSurface.withValues(alpha: 0.6), fontSize: 11), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => MusicService.instance.togglePlayPause(),
                            child: Icon(
                              MusicService.instance.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                              color: onSurface,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
