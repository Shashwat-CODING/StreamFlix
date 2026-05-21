import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/song_model.dart';
import '../models/media_item.dart';
import '../services/music_service.dart';
import '../services/bookmark_service.dart';
import '../widgets/ios_widgets.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  bool _showQueue = false;

  @override
  Widget build(BuildContext context) {
    final musicService = MusicService.instance;
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: musicService,
      builder: (context, _) {
        final song = musicService.currentSong;
        if (song == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.maybePop(context);
          });
          return const CupertinoPageScaffold(
            backgroundColor: CupertinoColors.black,
            child: SizedBox.shrink(),
          );
        }

        return CupertinoPageScaffold(
          backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
          child: Stack(
            children: [
              // Dynamic Colorful Backdrop Circles (Mesh Gradient Effect)
              Positioned.fill(
                child: ClipRect(
                  child: Stack(
                    children: [
                      // Base color dark or light matching theme
                      Container(color: isDark ? const Color(0xFF0D0D11) : const Color(0xFFF7F7FC)),
                      
                      // Animated colorful blur circle 1 (Primary color / Cyan / Violet)
                      Positioned(
                        top: -120,
                        left: -80,
                        width: 320,
                        height: 320,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.primaryColor.withValues(alpha: 0.35),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1.3, 1.3),
                              duration: 8.seconds,
                              curve: Curves.easeInOut,
                            ).move(
                              begin: const Offset(-20, -20),
                              end: const Offset(20, 20),
                              duration: 10.seconds,
                              curve: Curves.easeInOut,
                            ),
                      ),
                      
                      // Animated colorful blur circle 2 (Secondary / Violet / Pink)
                      Positioned(
                        bottom: 120,
                        right: -100,
                        width: 360,
                        height: 360,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFC73EE6),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                              begin: const Offset(1.2, 1.2),
                              end: const Offset(0.8, 0.8),
                              duration: 12.seconds,
                              curve: Curves.easeInOut,
                            ).move(
                              begin: const Offset(30, -30),
                              end: const Offset(-30, 30),
                              duration: 9.seconds,
                              curve: Curves.easeInOut,
                            ),
                      ),
                      
                      // Animated colorful blur circle 3 (Warm yellow / orange for dynamic contrast)
                      Positioned(
                        top: 250,
                        left: -120,
                        width: 280,
                        height: 280,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF9500),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                              begin: const Offset(0.7, 0.7),
                              end: const Offset(1.2, 1.2),
                              duration: 11.seconds,
                              curve: Curves.easeInOut,
                            ).move(
                              begin: const Offset(-10, 40),
                              end: const Offset(10, -40),
                              duration: 11.seconds,
                              curve: Curves.easeInOut,
                            ),
                      ),

                      // Blurred network image on top of standard solid/mesh
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: 0.35,
                          duration: 800.ms,
                          child: song.imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: song.imageUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Container(color: theme.primaryColor.withValues(alpha: 0.1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Backdrop Blur filter
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark 
                          ? CupertinoColors.black.withValues(alpha: 0.55) 
                          : CupertinoColors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _PlayerHeader(
                      song: song,
                      onClose: () => Navigator.pop(context),
                      onToggleQueue: () => setState(() => _showQueue = !_showQueue),
                      isQueueOpen: _showQueue,
                    ),

                    Expanded(
                      child: AnimatedSwitcher(
                        duration: 400.ms,
                        child: _showQueue
                            ? _QueueView(
                                queue: musicService.queue,
                                currentIndex: musicService.currentIndex,
                                isPlaying: musicService.isPlaying,
                              )
                            : _MainPlayerView(
                                song: song,
                                isPlaying: musicService.isPlaying,
                                isLoading: musicService.isLoading,
                              ),
                      ),
                    ),

                    if (!_showQueue)
                      _PlayerControls(
                        song: song,
                        isPlaying: musicService.isPlaying,
                        isLoading: musicService.isLoading,
                        position: musicService.position,
                        duration: musicService.duration,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  final SongModel song;
  final VoidCallback onClose;
  final VoidCallback onToggleQueue;
  final bool isQueueOpen;

  const _PlayerHeader({
    required this.song,
    required this.onClose,
    required this.onToggleQueue,
    required this.isQueueOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final color = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.08),
              ),
              child: Icon(CupertinoIcons.chevron_down, color: color, size: 22),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NOW PLAYING',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.5),
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artistName.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onToggleQueue,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isQueueOpen 
                    ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.15) 
                    : color.withValues(alpha: 0.08),
              ),
              child: Icon(
                isQueueOpen ? CupertinoIcons.music_note_list : CupertinoIcons.list_bullet,
                color: isQueueOpen ? CupertinoTheme.of(context).primaryColor : color,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainPlayerView extends StatelessWidget {
  final SongModel song;
  final bool isPlaying;
  final bool isLoading;

  const _MainPlayerView({
    required this.song,
    required this.isPlaying,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final artSize = size.width * 0.82;
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: AnimatedContainer(
            duration: 600.ms,
            curve: Curves.easeOutBack,
            width: isPlaying ? artSize : artSize * 0.88,
            height: isPlaying ? artSize : artSize * 0.88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: (song.imageUrl != null 
                          ? theme.primaryColor 
                          : CupertinoColors.black)
                      .withValues(alpha: isPlaying ? 0.38 : 0.15),
                  blurRadius: isPlaying ? 40 : 25,
                  spreadRadius: isPlaying ? 6 : 1,
                  offset: Offset(0, isPlaying ? 18 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: song.imageUrl != null
                  ? CachedNetworkImage(imageUrl: song.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: CupertinoColors.white.withValues(alpha: 0.1),
                      child: Icon(CupertinoIcons.music_note, size: 80, color: color),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.name,
                      style: GoogleFonts.outfit(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      song.artistName,
                      style: GoogleFonts.outfit(
                        color: color.withValues(alpha: 0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Heart Button for Bookmark
              GestureDetector(
                onTap: () {
                  BookmarkService.toggleBookmark(
                    MediaItem(
                      id: int.tryParse(song.id) ?? song.id.hashCode,
                      title: song.name,
                      artist: song.artistName,
                      artUri: song.imageUrl,
                      posterPath: song.imageUrl,
                      mediaType: 'music',
                      voteAverage: 0.0,
                    ),
                  );
                },
                child: ListenableBuilder(
                  listenable: BookmarkService.listChanged,
                  builder: (context, _) {
                    final isBookmarked = BookmarkService.isBookmarked(
                      int.tryParse(song.id) ?? song.id.hashCode,
                    );
                    return AnimatedContainer(
                      duration: 200.ms,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBookmarked 
                            ? const Color(0xFFFF2D55).withValues(alpha: 0.12) 
                            : color.withValues(alpha: 0.05),
                      ),
                      child: Icon(
                        isBookmarked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                        color: isBookmarked ? const Color(0xFFFF2D55) : color.withValues(alpha: 0.6),
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerControls extends StatelessWidget {
  final SongModel song;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;

  const _PlayerControls({
    required this.song,
    required this.isPlaying,
    required this.isLoading,
    required this.position,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProgressBar(
            position: position,
            duration: duration,
            color: color,
            onSeek: (d) => MusicService.instance.seekTo(d),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(
                  CupertinoIcons.shuffle,
                  color: MusicService.instance.isShuffled ? theme.primaryColor : color.withValues(alpha: 0.4),
                  size: 22,
                ),
                onPressed: () => MusicService.instance.toggleShuffle(),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.backward_fill, color: color, size: 28),
                onPressed: () => MusicService.instance.previous(),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => MusicService.instance.togglePlayPause(),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isLoading
                        ? CupertinoActivityIndicator(color: isDark ? CupertinoColors.black : CupertinoColors.white)
                        : Icon(
                            isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                            color: isDark ? CupertinoColors.black : CupertinoColors.white,
                            size: 32,
                          ),
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.forward_fill, color: color, size: 28),
                onPressed: () => MusicService.instance.next(),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(
                  CupertinoIcons.repeat,
                  color: MusicService.instance.isLooping ? theme.primaryColor : color.withValues(alpha: 0.4),
                  size: 22,
                ),
                onPressed: () => MusicService.instance.toggleLoop(),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showQualitySheet(context, song),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.waveform, color: color.withValues(alpha: 0.5), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        MusicService.instance.selectedQuality?.label.toUpperCase() ?? 'AUTO',
                        style: GoogleFonts.outfit(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQualitySheet(BuildContext context, SongModel song) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Audio Quality'),
        message: const Text('Select your preferred fidelity'),
        actions: song.qualities.reversed.map((q) {
          final isSelected = q.label == MusicService.instance.selectedQuality?.label;
          return CupertinoActionSheetAction(
            onPressed: () {
              MusicService.instance.changeQuality(q);
              Navigator.pop(context);
            },
            child: Text(
              q.label,
              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Color color;
  final ValueChanged<Duration> onSeek;

  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.color,
    required this.onSeek,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CupertinoSlider(
          value: duration.inSeconds > 0 ? position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()) : 0,
          max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1,
          onChanged: (v) => onSeek(Duration(seconds: v.toInt())),
          activeColor: color,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(position),
                style: GoogleFonts.outfit(
                  color: color.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _fmt(duration),
                style: GoogleFonts.outfit(
                  color: color.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueView extends StatelessWidget {
  final List<SongModel> queue;
  final int currentIndex;
  final bool isPlaying;

  const _QueueView({
    required this.queue,
    required this.currentIndex,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final color = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UP NEXT',
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${queue.length} songs',
                style: GoogleFonts.outfit(
                  color: color.withValues(alpha: 0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final s = queue[index];
              final isCurrent = index == currentIndex;
              return Container(
                key: ValueKey('queue_${s.id}_$index'),
                margin: const EdgeInsets.only(bottom: 8),
                child: GlassBox(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  borderRadius: 16,
                  color: isCurrent 
                      ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.12) 
                      : color.withValues(alpha: 0.03),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: s.imageUrl != null 
                            ? CachedNetworkImage(imageUrl: s.imageUrl!, width: 48, height: 48, fit: BoxFit.cover) 
                            : Container(width: 48, height: 48, color: color.withValues(alpha: 0.08)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: GoogleFonts.outfit(
                                color: isCurrent ? CupertinoTheme.of(context).primaryColor : color,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.artistName,
                              style: GoogleFonts.outfit(
                                color: color.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent && isPlaying) ...[
                        _MiniEqualizer(color: CupertinoTheme.of(context).primaryColor),
                        const SizedBox(width: 8),
                      ],
                      Icon(CupertinoIcons.line_horizontal_3, color: color.withValues(alpha: 0.15), size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniEqualizer extends StatelessWidget {
  final Color color;
  const _MiniEqualizer({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          final delay = (index * 150).ms;
          final duration = (600 + index * 100).ms;
          return Container(
            width: 2.5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.2),
            ),
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).custom(
            duration: duration,
            delay: delay,
            builder: (context, value, child) {
              final height = 3.0 + (value * 11.0); // height ranges from 3 to 14
              return SizedBox(height: height, child: child);
            },
          );
        }),
      ),
    );
  }
}
