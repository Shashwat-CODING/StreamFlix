import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/m3_loading.dart';
import '../utils/language_utils.dart';
import '../models/media_item.dart';
import '../services/streaming_service.dart';
import '../services/tmdb_service.dart';
import '../services/watch_history.dart';

class PlayerScreen extends StatefulWidget {
  final MediaDetail? item;
  final int? season;
  final int? episode;
  final int initialIndex;
  final List<MediaDetail>? playlist;

  const PlayerScreen({
    super.key,
    this.item,
    this.playlist,
    this.initialIndex = 0,
    this.season,
    this.episode,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _streamService = StreamingService();
  final _tmdb = TmdbService();

  late final player = Player();
  late final controller = VideoController(player);

  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';

  List<StreamSource> _sources = [];
  StreamSource? _selectedSource;

  // Tracks which CDN base URLs have fully failed.
  final Set<String> _failedCDNs = {};

  // FIX 2: _handlingError must always be reset, including in the "all failed" path.
  bool _handlingError = false;

  bool _isFullscreen = false;
  TvEpisode? _episodeDetail;

  Timer? _loadingTimer;
  int _messageIndex = 0;
  bool _showSlowLoadingHint = false;

  final List<String> _loadingMessages = [
    'Digging for streams...',
    'Funding server...',
    'Finding the best quality...',
    'Polishing the pixels...',
    'Optimizing buffer...',
    'Almost there...',
  ];

  void _startLoadingAnimation() {
    _stopLoadingAnimation();
    _messageIndex = 0;
    _showSlowLoadingHint = false;

    _loadingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _loadingMessages.length;
          if (timer.tick >= 10) {
            // ~30 seconds (3s * 10)
            _showSlowLoadingHint = true;
          }
        });
      }
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }

  @override
  void initState() {
    super.initState();
    // FIX 3: _currentIdx was set but never used — removed.

    WakelockPlus.enable().catchError((_) {});
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    if (widget.item != null) {
      final extra =
          (widget.item!.mediaType == 'tv' &&
              widget.season != null &&
              widget.episode != null)
          ? 'S${widget.season} E${widget.episode}'
          : null;
      WatchHistory.addItem(
        MediaItem(
          id: widget.item!.id,
          title: widget.item!.title,
          overview: widget.item!.overview,
          posterPath: widget.item!.posterPath,
          backdropPath: widget.item!.backdropPath,
          voteAverage: widget.item!.voteAverage,
          releaseDate: widget.item!.releaseDate,
          mediaType: widget.item!.mediaType,
          extraInfo: extra,
        ),
      );

      _loadMovieStreams();
      if (widget.item!.mediaType == 'tv' &&
          widget.season != null &&
          widget.episode != null) {
        _loadEpisodeDetail();
      }
    }
  }

  Future<void> _loadEpisodeDetail() async {
    final ep = await _tmdb.getTvEpisodeDetail(
      widget.item!.id,
      widget.season!,
      widget.episode!,
    );
    if (mounted) {
      setState(() => _episodeDetail = ep);
    }
  }

  Future<void> _loadMovieStreams() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = false;
      _sources = [];
      _selectedSource = null;
      _failedCDNs.clear();
      _handlingError = false;
    });
    _startLoadingAnimation();

    final isTv = widget.item!.mediaType == 'tv';
    debugPrint(
      '\n🎬 Loading ${isTv ? "TV" : "Movie"} | tmdbId=${widget.item!.id}',
    );

    final stream = isTv
        ? _streamService.getTvSources(
            widget.item!.id,
            widget.season ?? 1,
            widget.episode ?? 1,
          )
        : _streamService.getMovieSources(widget.item!.id);

    stream.listen(
      (newSources) {
        if (!mounted) return;
        setState(() {
          _sources.addAll(newSources);
          // Sort by priority DESC (higher first), then by serverId ASC
          _sources.sort((a, b) {
            final p = b.priority.compareTo(a.priority);
            if (p != 0) return p;
            return a.serverId.compareTo(b.serverId);
          });

          if (_selectedSource == null && _sources.isNotEmpty) {
            // Find first source whose CDN hasn't failed yet
            final bestSource = _sources.firstWhere(
              (s) => !_failedCDNs.contains(_getCDN(s.url)),
              orElse: () => _sources.first,
            );
            _selectedSource = bestSource;
            debugPrint('▶️  Starting with best available: $_selectedSource');
            _initPlayer(_selectedSource!.url);
          }
        });
      },
      onDone: () {
        if (!mounted) return;
        if (_sources.isEmpty) {
          setState(() {
            _loading = false;
            _error = true;
            _errorMsg =
                'No playback sources found for this ${isTv ? "show" : "movie"}.';
          });
          _stopLoadingAnimation();
          debugPrint('❌ No sources found after all servers checked');
        } else {
          debugPrint(
            '📦 Finished fetching all sources. Total: ${_sources.length}',
          );
        }
      },
      onError: (e) {
        debugPrint('❌ Stream error: $e');
        if (!mounted) return;
        if (_sources.isEmpty) {
          setState(() {
            _loading = false;
            _error = true;
            _errorMsg = 'Error fetching sources: $e';
          });
          _stopLoadingAnimation();
        }
      },
    );
  }

  String _getCDN(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return url;
    }
  }

  // ── Stream error handler ────────────────────────────────────────────────────

  void _handleStreamError(dynamic error, {StreamSource? failedSource}) {
    if (_handlingError) {
      debugPrint(
        '🔒 [handleStreamError] Already handling — skipping duplicate',
      );
      return;
    }
    _handlingError = true;

    final source = failedSource ?? _selectedSource;
    if (source == null) {
      _handlingError = false;
      return;
    }

    debugPrint('\n⚠️  Stream failed: $source');
    debugPrint('   Reason: $error');

    final cdn = _getCDN(source.url);
    final wasAlreadyFailed = _failedCDNs.contains(cdn);
    _failedCDNs.add(cdn);

    if (wasAlreadyFailed) {
      debugPrint('🔒 CDN $cdn was already blocked — skipping');
      _handlingError = false;
      return;
    }

    debugPrint('🚫 Blocking all sources from CDN: $cdn');

    if (_sources.isNotEmpty) {
      // FIX 4: Use nullable firstWhere so orElse returns null instead of
      // _sources.first (which could itself be a failed server), avoiding
      // a false "all servers failed" when valid sources still exist.
      final nextSource = _sources.cast<StreamSource?>().firstWhere(
        (s) => s != null && !_failedCDNs.contains(_getCDN(s.url)),
        orElse: () => null,
      );

      if (nextSource != null) {
        debugPrint('⏭️  Falling back to: $nextSource');
        if (mounted) {
          setState(() {
            _selectedSource = nextSource;
            _loading = true;
            _error = false;
          });
          _startLoadingAnimation();
        }
        // FIX 5: Reset guard BEFORE calling _initPlayer so errors
        // from the new source can be caught and handled correctly.
        _handlingError = false;
        _initPlayer(nextSource.url);
        return;
      }
    }

    // FIX 6: Reset guard in the "all servers failed" path too —
    // was previously left true, permanently blocking future error handling.
    debugPrint('❌ All servers failed. Showing error screen.');
    _handlingError = false;
    if (mounted) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMsg =
            'All available servers failed to load.\n${error.toString()}';
      });
      _stopLoadingAnimation();
    }
  }

  Future<void> _initPlayer(
    String url, {
    String? referrer,
    String? userAgent,
  }) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    _startLoadingAnimation();

    final bool skipHeaders = _selectedSource?.noHeaders == true;
    final Map<String, String> headers = skipHeaders
        ? {}
        : {
            'Referer':
                _selectedSource?.resolvedReferer ??
                referrer ??
                'https://rivestream.app/',
            'Origin':
                _selectedSource?.resolvedOrigin ??
                referrer ??
                'https://rivestream.app',
            'User-Agent':
                userAgent ??
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
          };

    debugPrint('\n▶️  Initializing media_kit Player');
    debugPrint('   URL: $url');

    // FIX 7: Pre-validate URL with a HEAD request before handing to media_kit.
    // This catches immediate 404s in ~8s instead of waiting for libmpv's
    // full internal timeout (which can be several minutes).
    final isValid = await _preValidateUrl(url, headers);
    if (!mounted) return;
    if (!isValid) {
      debugPrint(
        '❌ Pre-validation failed for Server ${_selectedSource?.serverId}',
      );
      _handleStreamError(
        'URL pre-validation failed (404 or unreachable)',
        failedSource: _selectedSource,
      );
      return;
    }

    try {
      await player.open(Media(url, httpHeaders: headers));
      if (mounted) {
        setState(() => _loading = false);
        _stopLoadingAnimation();
      }
    } catch (e) {
      debugPrint(
        '❌ Player init exception for Server ${_selectedSource?.serverId}: $e',
      );
      _handleStreamError(e, failedSource: _selectedSource);
    }
  }

  /// Quickly checks if a URL is reachable using a HEAD request.
  /// Returns false on 4xx/5xx errors or network failures.
  /// 10-second timeout to handle slow CDNs.
  Future<bool> _preValidateUrl(String url, Map<String, String> headers) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);

      final request = await client
          .headUrl(uri)
          .timeout(const Duration(seconds: 10));
      headers.forEach((k, v) => request.headers.set(k, v));

      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      client.close();

      final statusCode = response.statusCode;
      debugPrint('   Pre-validate status: $statusCode for $url');

      // Allow 2xx and 3xx. Fail on 4xx/5xx.
      return statusCode < 400;
    } catch (e) {
      debugPrint('   Pre-validate exception: $e');
      // Cannot reach URL at all — treat as invalid.
      return false;
    }
  }

  @override
  void dispose() {
    _resetSystemUI();
    player.dispose();
    _stopLoadingAnimation();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _resetSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);

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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: _actions,
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: _buildVideoContainer()),
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: _actions,
        child: Focus(
          autofocus: true,
          child: Scaffold(
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
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                16,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: _buildVideoContainer(),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ).copyWith(bottom: 40),
                                child: _buildMovieInfo(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: cs.outlineVariant.withOpacity(0.2),
                      ),
                      Expanded(flex: 3, child: _buildSidebar(cs)),
                    ],
                  );
                }

                return Column(
                  children: [
                    Stack(
                      children: [
                        SafeArea(
                          bottom: false,
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _buildVideoContainer(),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(child: _buildFloatingTopBar()),
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.item != null) _buildMovieInfo(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            children: [
              _glassIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              Text(
                'Playback Settings',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              _sidebarTile(
                icon: Icons.high_quality_rounded,
                title: 'Resolution',
                subtitle: player.state.track.video.id == 'auto'
                    ? 'Auto'
                    : 'Manual',
                onTap: _showVideoTrackSelection,
                cs: cs,
              ),
              _sidebarTile(
                icon: Icons.dns_rounded,
                title: 'Source / Server',
                subtitle: _selectedSource?.quality ?? 'Select',
                onTap: _showSourcePicker,
                cs: cs,
              ),
              _sidebarTile(
                icon: Icons.audiotrack_rounded,
                title: 'Audio Tracks',
                subtitle: 'Change Language',
                onTap: _showAudioSelection,
                cs: cs,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Text(
                  'SHORTCUTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.grey,
                  ),
                ),
              ),
              const _ShortcutInfo(keyLabel: 'Space', action: 'Play / Pause'),
              const _ShortcutInfo(keyLabel: 'F', action: 'Fullscreen'),
              const _ShortcutInfo(keyLabel: '← / →', action: 'Seek 10s'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebarTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _buildFloatingTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _glassIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Widget _buildVideoContainer() {
    if (_loading) return _buildLoadingView();
    if (_error) return _buildErrorView();

    return MaterialVideoControlsTheme(
      normal: MaterialVideoControlsThemeData(
        topButtonBar: [
          const Spacer(),
          MaterialCustomButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      fullscreen: MaterialVideoControlsThemeData(
        topButtonBar: [
          const Spacer(),
          MaterialCustomButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      child: Stack(
        children: [
          Video(controller: controller, controls: AdaptiveVideoControls),
          // Always-visible settings button in top-right (desktop fallback)
          Positioned(
            top: 12,
            right: 12,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _showSettingsSheet,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Sheets ───────────────────────────────────────────────────────────

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
                'Playback Settings',
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
                icon: CupertinoIcons.layers_alt,
                label: 'Change Server',
                cs: cs,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSourcePicker();
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

    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No audio tracks available yet. Try again after playback starts.',
          ),
        ),
      );
      return;
    }

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
                    String label;
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

    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No video tracks available yet. Try again after playback starts.',
          ),
        ),
      );
      return;
    }

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
                    String label;
                    if (track.id == 'auto') {
                      label = 'Auto';
                    } else if (track.id == 'no') {
                      label = 'Disabled';
                    } else {
                      final List<String> parts = [];
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
                        label = parts.join(' · ');
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

  void _showSourcePicker() {
    final cs = Theme.of(context).colorScheme;
    final availableSources = _sources
        .where((s) => !_failedCDNs.contains(_getCDN(s.url)))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withOpacity(0.85),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Center(child: _dragHandle()),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.high_quality_rounded,
                    color: cs.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Quality',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${availableSources.length} sources',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: availableSources.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final s = availableSources[i];
                  final active = s == _selectedSource;
                  // Determine quality icon
                  IconData qualIcon = Icons.sd_rounded;
                  final q = s.quality.toLowerCase();
                  if (q.contains('4k') || q.contains('2160'))
                    qualIcon = Icons.hd_rounded;
                  else if (q.contains('1080'))
                    qualIcon = Icons.hd_rounded;
                  else if (q.contains('720'))
                    qualIcon = Icons.hd_rounded;
                  else if (q.contains('480') || q.contains('480'))
                    qualIcon = Icons.sd_rounded;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: active
                          ? cs.primary.withOpacity(0.15)
                          : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? cs.primary.withOpacity(0.5)
                            : cs.outlineVariant.withOpacity(0.4),
                        width: active ? 1.5 : 0.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: active
                              ? cs.primary.withOpacity(0.2)
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          qualIcon,
                          color: active ? cs.primary : cs.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        s.quality,
                        style: GoogleFonts.inter(
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 14,
                          color: active ? cs.primary : cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        s.serverId == 0
                            ? s.source
                            : '${s.source} · Server ${s.serverId}',
                        style: GoogleFonts.inter(
                          color: active
                              ? cs.primary.withOpacity(0.7)
                              : cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: active
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Playing',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!active) {
                          debugPrint('\n🔀 Manual source switch → $s');
                          setState(() => _selectedSource = s);
                          _initPlayer(s.url);
                        }
                      },
                    ),
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

  // ── Loading & Error views ───────────────────────────────────────────────────

  Widget _buildLoadingView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const M3Loading(size: 64),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 0.2),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutCubic)),
                  ),
                  child: child,
                ),
              );
            },
            child: Text(
              _loadingMessages[_messageIndex],
              key: ValueKey<int>(_messageIndex),
              style: GoogleFonts.outfit(
                color: cs.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (_showSlowLoadingHint) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: cs.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.error.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, color: cs.error, size: 18),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Taking too long? Try changing the server.',
                      style: GoogleFonts.inter(
                        color: cs.onErrorContainer,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(
              begin: const Offset(0.9, 0.9),
              curve: Curves.easeOutBack,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child:
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: cs.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Playback Failure',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loadMovieStreams,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'Retry Connection',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(
              begin: const Offset(0.9, 0.9),
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }

  // ── Info sections ───────────────────────────────────────────────────────────

  Widget _buildMovieInfo() {
    final item = widget.item!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (_episodeDetail != null)
                    ? 'S${widget.season} E${widget.episode}: ${_episodeDetail!.name}'
                    : item.title,
                style: GoogleFonts.outfit(
                  fontSize: 28, // Reduced slightly for long episode titles
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1.0,
                  color: cs.onSurface,
                ),
              ).animate().fadeIn().slideX(begin: -0.05),
              if (_episodeDetail != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _infoBadge(item.year, Icons.calendar_today_rounded),
                  _infoBadge(
                    item.ratingStr,
                    Icons.star_rounded,
                    iconColor: Colors.amber,
                  ),
                  if (item.runtime != null)
                    _infoBadge('${item.runtime}m', Icons.schedule_rounded),
                ],
              ).animate().fadeIn(delay: 100.ms),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'SYNOPSIS',
            style: GoogleFonts.outfit(
              color: cs.primary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          Text(
            _episodeDetail?.overview ??
                item.overview ??
                'No description available.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 40),
          Text(
            'TOP CAST',
            style: GoogleFonts.outfit(
              color: cs.primary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: item.cast.length.clamp(0, 10),
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemBuilder: (_, i) {
                final p = item.cast[i];
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: cs.surfaceContainerHighest,
                      backgroundImage: p.fullProfileUrl.isNotEmpty
                          ? CachedNetworkImageProvider(p.fullProfileUrl)
                          : null,
                      child: p.fullProfileUrl.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              color: cs.onSurfaceVariant,
                              size: 32,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 72,
                      child: Text(
                        p.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),
        ],
      ),
    );
  }

  Widget _infoBadge(String label, IconData icon, {Color? iconColor}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ── Keyboard Shortcuts ──────────────────────────────────────────────────────

  late final Map<ShortcutActivator, Intent> _shortcuts = {
    const SingleActivator(LogicalKeyboardKey.space): const _PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF):
        const _ToggleFullscreenIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const _SeekForwardIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const _SeekBackwardIntent(),
  };

  late final Map<Type, Action<Intent>> _actions = {
    _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
      onInvoke: (_) => setState(() => player.playOrPause()),
    ),
    _ToggleFullscreenIntent: CallbackAction<_ToggleFullscreenIntent>(
      onInvoke: (_) => _toggleFullscreen(),
    ),
    _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(
      onInvoke: (_) =>
          player.seek(player.state.position + const Duration(seconds: 10)),
    ),
    _SeekBackwardIntent: CallbackAction<_SeekBackwardIntent>(
      onInvoke: (_) =>
          player.seek(player.state.position - const Duration(seconds: 10)),
    ),
  };
}

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _ToggleFullscreenIntent extends Intent {
  const _ToggleFullscreenIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}

class _SeekBackwardIntent extends Intent {
  const _SeekBackwardIntent();
}

class _ShortcutInfo extends StatelessWidget {
  final String keyLabel;
  final String action;

  const _ShortcutInfo({required this.keyLabel, required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            child: Text(
              keyLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            action,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
