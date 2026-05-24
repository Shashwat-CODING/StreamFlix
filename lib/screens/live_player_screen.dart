import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart';

import '../widgets/fvp_controls.dart';

import '../widgets/ios_widgets.dart';
import '../theme/app_theme.dart';
import '../models/channel.dart';
import '../utils/language_utils.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

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

// ── ColorScheme Shim ─────────────────────────────────────────────────────────



class _LivePlayerScreenState extends State<LivePlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  dynamic _mediaInfo;

  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';

  late Channel _currentChannel;
  late int _currentIdx;

  int _currentStreamIdx = 0;
  bool _handlingError = false;
  bool _isFullscreen = false;

  void _showToast(String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

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
      const SystemUiOverlayStyle(statusBarColor: const Color(0x00000000)),
    );

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      if (_currentChannel.streams.isEmpty) throw Exception('No streams found');
      if (_currentStreamIdx >= _currentChannel.streams.length) {
        throw Exception('All streams for this channel failed');
      }

      final stream = _currentChannel.streams[_currentStreamIdx];
      debugPrint(
        '📺 Initializing Live Player: ${_currentChannel.name} | Stream: ${stream.title} (${stream.url})',
      );

      // Set default headers for live streams, respecting source-specific overrides
      final Map<String, String> headers = {
        'Referer': stream.referrer ?? 'https://rivestream.app/',
        'Origin': stream.referrer ?? 'https://rivestream.app',
        'User-Agent': stream.userAgent ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      };

      if (stream.headers != null) {
        headers.addAll(stream.headers!);
      }

      _videoPlayerController?.pause();
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      if (mounted) setState(() => _loading = true);

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
      
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(stream.url), httpHeaders: headers);
      await _videoPlayerController!.initialize();
      try {
        _mediaInfo = _videoPlayerController!.getMediaInfo();
      } catch (_) {}
      _videoPlayerController!.play();

      if (mounted) {
        setState(() => _loading = false);
      }

      debugPrint('✅ FVP Player initialized for Live');
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
        index >= widget.playlist!.length) {
      return;
    }

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

  @override
  void dispose() {
    _resetSystemUI();
    _videoPlayerController?.dispose();
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
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Center(child: _buildVideoContainer()),
      );
    }

    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : theme.scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 950;
          final cs = theme.colorScheme;

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
                Container(
                  width: 1,
                  color: CupertinoColors.separator.withValues(alpha: 0.2),
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
                      const NativeAdWidget(size: NativeAdSize.small),
                      _buildChannelHeader(cs),
                      Container(height: 0.5, color: CupertinoColors.separator),
                      if (widget.playlist != null) ...[
                        _buildPlaylist(cs),
                        BannerAdWidget(),
                      ],
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
    final cs = CupertinoTheme.of(context).colorScheme;
    if (_loading) return _buildLoading(cs);
    if (_error) return _buildError(cs);

    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      return FvpCustomControls(
        controller: _videoPlayerController!,
        onFullscreenToggle: _toggleFullscreen,
      );
    }
    return Container(color: CupertinoColors.black);
  }

  Widget _buildFloatingTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _glassIconButton(
            icon: FluentIcons.chevron_left_24_regular,
            onPressed: () => Navigator.pop(context),
          ),
          Row(
            children: [
              _glassIconButton(
                icon: FluentIcons.share_24_regular,
                onPressed: _shareChannel,
              ),
              const SizedBox(width: 8),
              _glassIconButton(
                icon: FluentIcons.settings_24_regular,
                onPressed: _showSettingsSheet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareChannel() {
    final url = '${ApiService.websiteUrl}/watch/iptv?id=${_currentChannel.id}';
    Share.share('Watch ${_currentChannel.name} Live on Luxa!\n\nWatch here: $url');
  }

  void _showSettingsSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CompactActionSheet(
        title: const Text('Stream Settings'),
        message: const Text('Configure live stream properties'),
        actions: [
          CompactActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showVideoTrackSelection();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.movies_and_tv_24_regular, size: 16),
                SizedBox(width: 8),
                Text('Video Quality'),
              ],
            ),
          ),
          CompactActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showAudioSelection();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.music_note_2_24_regular, size: 16),
                SizedBox(width: 8),
                Text('Audio Tracks'),
              ],
            ),
          ),
        ],
        cancelButton: CompactActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showAudioSelection() {
    if (_mediaInfo == null || _mediaInfo.audio == null) {
      _showToast('No internal audio tracks available for this stream.');
      return;
    }

    final audioTracks = _mediaInfo.audio as List;
    final activeTracks = _videoPlayerController?.getActiveAudioTracks() ?? [];

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CompactActionSheet(
        title: const Text('Audio Tracks'),
        message: const Text('Select embedded audio channel'),
        actions: List.generate(audioTracks.length, (index) {
          final track = audioTracks[index];
          final trackId = track.index ?? index;
          final lang = track.metadata?['language'] ?? 'Track ${index + 1}';
          final isActive = activeTracks.contains(trackId);

          return CompactActionSheetAction(
            onPressed: () {
              _videoPlayerController?.setAudioTracks([trackId]);
              Navigator.pop(ctx);
            },
            child: Text(
              '$lang (${track.codec ?? "Unknown"}) ${isActive ? "✓" : ""}',
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
        cancelButton: CompactActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showVideoTrackSelection() {
    if (_mediaInfo == null || _mediaInfo.video == null) {
      _showToast('No video tracks available');
      return;
    }

    final videoTracks = _mediaInfo.video as List;
    final activeTracks = _videoPlayerController?.getActiveVideoTracks() ?? [];

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CompactActionSheet(
        title: const Text('Internal Video Tracks'),
        message: const Text('Select video stream track'),
        actions: List.generate(videoTracks.length, (index) {
          final track = videoTracks[index];
          final trackId = track.index ?? index;
          final isActive = activeTracks.contains(trackId);
          final codec = track.codec ?? 'Unknown';
          final label = 'Track ${index + 1} ($codec)';

          return CompactActionSheetAction(
            onPressed: () {
              _videoPlayerController?.setVideoTracks([trackId]);
              Navigator.pop(ctx);
            },
            child: Text(
              '$label ${isActive ? "✓" : ""}',
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
        cancelButton: CompactActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    double iconSize = 22,
  }) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: isDark ? const Color(0x662C2C2E) : const Color(0x66FFFFFF),
          child: CupertinoButton(
            padding: const EdgeInsets.all(10),
            minSize: 0,
            onPressed: onPressed,
            child: Icon(
              icon,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelHeader(CupertinoColorScheme cs) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Container
          Container(
            width: 72,
            height: 72,
            decoration: AppTheme.brutalistDecoration(
              context: context,
              color: isDark ? AppTheme.darkSlate : CupertinoColors.white,
              borderRadius: 12.0,
            ),
            padding: const EdgeInsets.all(10),
            child: _currentChannel.hasLogo
                ? CachedNetworkImage(
                    imageUrl: _currentChannel.logoUrl!,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    FluentIcons.video_clip_24_filled,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
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
                      (_currentChannel.group ?? 'STREAM').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _currentChannel.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
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
        color: CupertinoColors.systemRed,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.circle_24_filled, color: CupertinoColors.white, size: 6)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1.seconds),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist(CupertinoColorScheme cs) {
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
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
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final ch = widget.playlist![i];
            final active = i == _currentIdx;
            final theme = CupertinoTheme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _switchChannel(i),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.brutalistDecoration(
                  context: context,
                  color: active
                      ? AppTheme.neonYellow
                      : (isDark ? AppTheme.darkSlate : CupertinoColors.white),
                  borderRadius: 12.0,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? CupertinoColors.black : CupertinoColors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? CupertinoColors.systemGrey6 : CupertinoColors.systemGrey5,
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: ch.hasLogo
                          ? CachedNetworkImage(
                              imageUrl: ch.logoUrl!,
                              fit: BoxFit.contain,
                            )
                          : Icon(
                              FluentIcons.tv_24_filled,
                              color: isDark ? CupertinoColors.white : CupertinoColors.black,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        ch.name,
                        style: TextStyle(
                          fontWeight: active ? FontWeight.bold : FontWeight.w500,
                          fontSize: 15,
                          color: active
                              ? CupertinoColors.white
                              : (isDark ? CupertinoColors.white : CupertinoColors.black),
                        ),
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 8),
                      const Icon(FluentIcons.sound_wave_circle_24_regular, color: CupertinoColors.white, size: 24)
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

  Widget _buildLoading(CupertinoColorScheme cs) {
    return const Center(child: IOSLoading(message: 'Buffering Live Stream...'));
  }

  Widget _buildError(CupertinoColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FluentIcons.error_circle_24_regular,
              color: CupertinoColors.systemRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMsg,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _initPlayer,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.arrow_clockwise_24_regular),
                  const SizedBox(width: 8),
                  const Text('Try Again'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



