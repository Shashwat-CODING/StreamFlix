import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../widgets/m3_loading.dart';
import '../models/channel.dart';
import '../utils/language_utils.dart';

class LivePlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel>? playlist;
  final int initialIndex;

  const LivePlayerScreen({
    super.key,
    required this.channel,
    this.playlist,
    this.initialIndex = 0,
  });

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  late final player = Player();
  late final controller = VideoController(player);

  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';

  late Channel _currentChannel;
  late int _currentIdx;

  int _currentStreamIdx = 0;
  bool _handlingError = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _currentIdx = widget.initialIndex;

    WakelockPlus.enable().catchError((_) {});
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = false;
      });

    try {
      if (_currentChannel.streams.isEmpty) throw Exception('No streams found');
      if (_currentStreamIdx >= _currentChannel.streams.length) {
        throw Exception('All streams for this channel failed');
      }

      final stream = _currentChannel.streams[_currentStreamIdx];
      debugPrint(
        '📺 Initializing Live Player: ${_currentChannel.name} | Stream: ${stream.title} (${stream.url})',
      );

      // Set default headers for live streams
      final Map<String, String> headers = {
        'Referer': 'https://rivestream.app/',
        'Origin': 'https://rivestream.app',
      };

      // FIX: Pre-validate URL with a HEAD request before handing to media_kit.
      final isValid = await _preValidateUrl(stream.url, headers);
      if (!mounted) return;
      if (!isValid) {
        debugPrint('❌ Pre-validation failed for Live Stream');
        _handleLiveStreamError(
          'URL pre-validation failed (404 or unreachable)',
        );
        return;
      }

      await player.open(Media(stream.url, httpHeaders: headers));

      if (mounted) {
        setState(() => _loading = false);
      }

      debugPrint('✅ media_kit Player initialized for Live');
    } catch (e) {
      debugPrint('❌ Live player init exception: $e');
      _handleLiveStreamError(e.toString());
    }
  }

  Future<bool> _preValidateUrl(String url, Map<String, String> headers) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);

      final request = await client
          .headUrl(uri)
          .timeout(const Duration(seconds: 8));
      headers.forEach((k, v) => request.headers.set(k, v));

      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      client.close();

      final statusCode = response.statusCode;
      debugPrint('   Pre-validate status: $statusCode for $url');

      return statusCode < 400;
    } catch (e) {
      debugPrint('   Pre-validate exception: $e');
      return false;
    }
  }

  void _handleLiveStreamError(String msg) {
    if (_handlingError) return;
    _handlingError = true;

    if (_currentStreamIdx + 1 < _currentChannel.streams.length) {
      _currentStreamIdx++;
      print('⏭️ Falling back to next stream index: $_currentStreamIdx');
      _handlingError =
          false; // Reset to allow subsequent fallbacks if this one fails
      _initPlayer();
    } else {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMsg = msg;
          _loading = false;
          _handlingError = false;
        });
      }
    }
  }

  Future<void> _switchChannel(int index) async {
    if (widget.playlist == null ||
        index < 0 ||
        index >= widget.playlist!.length)
      return;

    setState(() {
      _currentIdx = index;
      _currentChannel = widget.playlist![index];
      _currentStreamIdx = 0; // Reset stream index for new channel
      _loading = true;
      _error = false;
      _handlingError = false;
    });

    await _initPlayer();
  }

  Future<void> _changeAudioTrack(dynamic track) async {
    print(
      'ℹ️ Audio track selection via video_player API is limited. Track: $track',
    );
  }

  @override
  void dispose() {
    _resetSystemUI();
    player.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _resetSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      _resetSystemUI();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: _buildVideoContainer()),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 950;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              children: [
                                _buildVideoContainer(),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: _buildFloatingTopBar(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ).copyWith(bottom: 40),
                          child: _buildChannelHeader(cs),
                        ),
                      ),
                    ],
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: cs.outlineVariant.withOpacity(0.2),
                ),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.playlist != null) ...[
                          _buildPlaylist(cs),
                          const SizedBox(height: 100),
                        ] else ...[
                          const SizedBox(height: 100),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile Layout
          return Column(
            children: [
              // Video Section (Top)
              Stack(
                children: [
                  SafeArea(
                    bottom: false,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildVideoContainer(),
                    ),
                  ),
                  // Floating Top Bar (Custom UI)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(child: _buildFloatingTopBar()),
                  ),
                ],
              ),
              // Details Section (Bottom)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChannelHeader(cs),
                      const Divider(indent: 24, endIndent: 24, height: 1),
                      if (widget.playlist != null) _buildPlaylist(cs),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoContainer() {
    if (_loading) return _buildLoading(Theme.of(context).colorScheme);
    if (_error) return _buildError(Theme.of(context).colorScheme);

    return MaterialVideoControlsTheme(
      normal: MaterialVideoControlsThemeData(
        topButtonBar: [
          const Spacer(),
          MaterialCustomButton(
            icon: const Icon(CupertinoIcons.settings, color: Colors.white),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      fullscreen: const MaterialVideoControlsThemeData(),
      child: Video(controller: controller, controls: AdaptiveVideoControls),
    );
  }

  Widget _buildFloatingTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _glassIconButton(
            icon: CupertinoIcons.chevron_back,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withOpacity(0.85),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Center(child: _dragHandle()),
              const SizedBox(height: 20),
              Text(
                'Stream Settings',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              _sheetOption(
                icon: CupertinoIcons.film,
                label: 'Video Quality',
                cs: cs,
                onTap: () {
                  Navigator.pop(ctx);
                  _showVideoTrackSelection();
                },
              ),
              const SizedBox(height: 8),
              _sheetOption(
                icon: CupertinoIcons.music_note_2,
                label: 'Audio Tracks',
                cs: cs,
                onTap: () {
                  Navigator.pop(ctx);
                  _showAudioSelection();
                },
              ),
            ],
          ),
        ),
      ),
        ),
      ),
      ),
    );
  }

  void _showAudioSelection() {
    final tracks = player.state.tracks.audio;
    if (tracks.isEmpty) return;

    final cs = Theme.of(context).colorScheme;
    final selectedTrack = player.state.track.audio;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withOpacity(0.85),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Center(child: _dragHandle()),
              const SizedBox(height: 20),
              Text(
                'Audio Tracks',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isActive = track == selectedTrack;
                    String label = '';
                    if (track.id == 'auto') {
                      label = 'Auto';
                    } else if (track.id == 'no') {
                      label = 'Disabled';
                    } else {
                      label = LanguageUtils.getLabel(
                        track.language,
                        track.title,
                        index,
                      );
                    }
                    return _sheetTrackTile(
                      label: label,
                      isActive: isActive,
                      icon: CupertinoIcons.music_note_2,
                      cs: cs,
                      onTap: () {
                        player.setAudioTrack(track);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
        ),
      ),
      ),
    );
  }

  void _showVideoTrackSelection() {
    final tracks = player.state.tracks.video;
    if (tracks.isEmpty) return;

    final cs = Theme.of(context).colorScheme;
    final selectedTrack = player.state.track.video;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withOpacity(0.85),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Center(child: _dragHandle()),
              const SizedBox(height: 20),
              Text(
                'Video Quality',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isActive = track == selectedTrack;
                    String label = '';
                    if (track.id == 'auto') {
                      label = 'Auto';
                    } else if (track.id == 'no') {
                      label = 'Disabled';
                    } else {
                      List<String> parts = [];
                      if (track.h != null) {
                        parts.add('${track.h}p');
                      } else if (track.w != null) {
                        parts.add('${track.w}w');
                      }
                      if (track.bitrate != null && track.bitrate! > 0) {
                        parts.add('${(track.bitrate! / 1000).round()} kbps');
                      }
                      if (track.fps != null && track.fps! > 0) {
                        parts.add('${track.fps!.round()} fps');
                      }
                      if (track.codec != null && track.codec!.isNotEmpty) {
                        parts.add(track.codec!.toUpperCase());
                      }
                      if (parts.isNotEmpty) {
                        label = parts.join(' \u00b7 ');
                        if (track.title != null &&
                            track.title!.toLowerCase() != 'und') {
                          label += ' (${track.title})';
                        }
                      } else if (track.title != null &&
                          track.title!.toLowerCase() != 'und') {
                        label = track.title!;
                      } else {
                        label = 'Track ${index + 1}';
                      }
                    }
                    return _sheetTrackTile(
                      label: label,
                      isActive: isActive,
                      icon: CupertinoIcons.film,
                      cs: cs,
                      onTap: () {
                        player.setVideoTrack(track);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
        ),
      ),
      ),
    );
  }

  Widget _dragHandle() {
    return Container(
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required ColorScheme cs,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white.withOpacity(0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetTrackTile({
    required String label,
    required bool isActive,
    required IconData icon,
    required ColorScheme cs,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? cs.primary.withOpacity(0.12)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: cs.primary.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isActive ? CupertinoIcons.checkmark_circle_fill : icon,
              color: isActive ? cs.primary : Colors.white.withOpacity(0.5),
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? cs.primary : Colors.white,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Active',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 48,
    double iconSize = 24,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: iconSize),
    );
  }

  Widget _buildChannelHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Container
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: _currentChannel.hasLogo
                ? CachedNetworkImage(
                    imageUrl: _currentChannel.logoUrl!,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    CupertinoIcons.play_rectangle_fill,
                    color: cs.primary,
                    size: 36,
                  ),
          ),
          const SizedBox(width: 20),
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildLiveBadge(),
                    const SizedBox(width: 8),
                    Text(
                      _currentChannel.group ?? 'STREAM',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _currentChannel.name,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.circle_fill, color: Colors.white, size: 6)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1.seconds),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Channels',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${widget.playlist!.length} total',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: widget.playlist!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final ch = widget.playlist![i];
            final active = i == _currentIdx;
            return InkWell(
              onTap: () => _switchChannel(i),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: active
                      ? cs.secondaryContainer
                      : cs.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? cs.primary.withOpacity(0.2)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: ch.hasLogo
                          ? CachedNetworkImage(
                              imageUrl: ch.logoUrl!,
                              fit: BoxFit.contain,
                            )
                          : Icon(
                              CupertinoIcons.tv_fill,
                              color: cs.primary,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        ch.name,
                        style: GoogleFonts.outfit(
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 16,
                          color: active
                              ? cs.onSecondaryContainer
                              : cs.onSurface,
                        ),
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 8),
                      Icon(CupertinoIcons.waveform, color: cs.primary, size: 24)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleY(begin: 0.8, end: 1.4),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return const Center(child: M3Loading(message: 'Buffering Live Stream...'));
  }

  Widget _buildError(ColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMsg,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: _initPlayer,
              icon: const Icon(CupertinoIcons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
