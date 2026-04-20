import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';

import 'package:fvp/fvp.dart';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/m3_loading.dart';
import '../utils/language_utils.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/streaming_service.dart';
import '../models/api_models.dart';
import '../models/download_item.dart';
import '../services/watch_history.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/fvp_controls.dart';

class PlayerScreen extends StatefulWidget {
  final MediaDetail? item;
  final int? season;
  final int? episode;
  final int initialIndex;
  final List<MediaDetail>? playlist;
  final String? offlinePath;

  const PlayerScreen({
    super.key,
    this.item,
    this.playlist,
    this.initialIndex = 0,
    this.season,
    this.episode,
    this.offlinePath,
  });



  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _api = ApiService.instance;
  final _streamService = StreamingService.instance;

  VideoPlayerController? _videoPlayerController;

  dynamic _mediaInfo;

  bool _loading = true;
  bool _fetchingDubs = false;
  bool _error = false;
  String _errorMsg = '';

  List<StreamSource> _sources = [];
  StreamSource? _selectedSource;
  String? _selectedLanguage;

  // Tracks which CDN base URLs have fully failed.
  final Set<String> _failedCDNs = {};
  bool _isStreamDone = false;

  // FIX 2: _handlingError must always be reset, including in the "all failed" path.
  bool _handlingError = false;

  bool _isFullscreen = false;
  bool _hasSeeked = false;
  TvEpisode? _episodeDetail;

  Timer? _loadingTimer;
  int _messageIndex = 0;
  final List<String> _loadingMessages = [
    'Setting the stage...',
    'Finding best streams...',
    'Preparing stream...',
    'Polishing pixels...',
    'Almost ready...',
    'Rolling soon...',
  ];

  void _startLoadingAnimation() {
    _stopLoadingAnimation();
    _messageIndex = 0;

    _loadingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _loadingMessages.length;
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
          position: widget.item!.position,
          duration: widget.item!.duration,
        ),
      );
    }

    if (widget.offlinePath != null) {
      _initOfflinePlayer();
    } else if (widget.item != null) {
      _loadMovieStreams();
      if (widget.item!.mediaType == 'tv' &&
          widget.season != null &&
          widget.episode != null) {
        _loadEpisodeDetail();
      }
    }
  }

  void _initOfflinePlayer() {
    setState(() {
      _loading = false;
      _error = false;
    });
    _initPlayer(widget.offlinePath!);
  }

  Future<void> _loadEpisodeDetail() async {
    final ep = await _api.getTvEpisodeDetail(
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
      _isStreamDone = false;
      _handlingError = false;
      _selectedLanguage = null; // Reset on new movie/episode load
    });
    _startLoadingAnimation();

    final isTv = widget.item!.mediaType == 'tv';
    debugPrint(
      '\n🎬 Loading ${isTv ? "TV" : "Movie"} | tmdbId=${widget.item!.id}',
    );

    final stream = _streamService.getSources(
      widget.item!.mediaType,
      widget.item!.id,
      season: widget.season,
      episode: widget.episode,
    );

    stream.listen(
      (newSources) {
        if (!mounted) return;
        setState(() {
          _sources.addAll(newSources);
          // Sort by priority DESC (higher first), then by fileSize ASC (smaller first)
          _sources.sort((a, b) {
            final p = b.priority.compareTo(a.priority);
            if (p != 0) return p;
            
            // If priorities same, prefer smaller fileSize (0 means unknown, push to end)
            if (a.fileSize > 0 && b.fileSize > 0) {
              return a.fileSize.compareTo(b.fileSize);
            } else if (a.fileSize > 0) {
              return -1; // a is known, b is unknown, a first
            } else if (b.fileSize > 0) {
              return 1; // b is known, a is unknown, b first
            }
            
            return a.serverId.compareTo(b.serverId);
          });

          if (_selectedSource == null && _sources.isNotEmpty) {
            // Find first source whose CDN hasn't failed yet, preferring current language if set
            final bestSource = _sources.cast<StreamSource?>().firstWhere(
              (s) => s != null && !_failedCDNs.contains(_getCDN(s.url)) && (s.language == _selectedLanguage),
              orElse: () => _sources.cast<StreamSource?>().firstWhere(
                (s) => s != null && !_failedCDNs.contains(_getCDN(s.url)),
                orElse: () => null,
              ),
            );
            
            if (bestSource != null) {
              _selectedSource = bestSource;
              debugPrint('▶️  Starting with best available: $_selectedSource');
              _initPlayer(_selectedSource!.url);
            }
          }
        });
      },
      onDone: () {
        if (!mounted) return;
        _isStreamDone = true;
        
        final bool allSourcesFailed = _sources.isNotEmpty && 
            _sources.every((s) => _failedCDNs.contains(_getCDN(s.url)));
            
        if (_sources.isEmpty || allSourcesFailed) {
          final msg = allSourcesFailed ? 'All available servers failed to load. Please try again.' : 'No playback sources found for this ${isTv ? "show" : "movie"}.';
          setState(() {
            _loading = false;
            _error = true;
            _errorMsg = msg;
          });
          _stopLoadingAnimation();
          _showErrorDialog(msg);
          debugPrint('❌ No valid sources found after all servers checked');
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
          final msg = 'Error fetching sources: $e';
          setState(() {
            _loading = false;
            _error = true;
            _errorMsg = msg;
          });
          _stopLoadingAnimation();
          _showErrorDialog(msg);
        }
      },
    );
  }

  String _getCDN(String url) {
    try {
      final uri = Uri.parse(url);
      // If the URL is a proxying service, try to block the target host instead of the proxy itself.
      final target = uri.queryParameters['url'] ?? uri.queryParameters['link'];
      if (target != null && target.startsWith('http')) {
        final targetUri = Uri.parse(target);
        return '${targetUri.scheme}://${targetUri.host}';
      }
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return url;
    }
  }

  void _startDownload() async {
    if (widget.item == null) return;

    // Show loading dialog while fetching and validating dedicated download sources
    _showLoadingDownloadSourcesDialog();
    
    try {
      final downloadSources = await _streamService.fetchDownloadSources(
        widget.item!.mediaType,
        widget.item!.id,
        season: widget.season,
        episode: widget.episode,
      );

      if (!mounted) return;

      if (downloadSources.isEmpty) {
        Navigator.pop(context); // Pop loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No high-speed download sources found for this title.'))
        );
        return;
      }

      // Pre-validation pass — validate up to 5 sources in parallel (with timeout)
      final List<StreamSource> validSources = [];
      final results = await Future.wait(
        downloadSources.map((source) async {
          final Map<String, String> headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
          };
          if (source.referer != null && source.referer!.isNotEmpty) {
            headers['Referer'] = source.referer!;
          }
          if (source.origin != null && source.origin!.isNotEmpty) {
            headers['Origin'] = source.origin!;
          }
          if (source.headers != null) headers.addAll(source.headers!);

          final code = await _preValidateUrl(source.url, headers);
          return (source, code);
        }),
        eagerError: false, // Keep going even if some fail
      );

      // Filter: accept anything that isn't a definitive failure (401, 403, 404, 410)
      // Status 200 = valid. We use _preValidateUrl which already normalises codes.
      for (final res in results) {
        final code = res.$2;
        if (code < 400 || code == 206) {
          validSources.add(res.$1);
        } else {
          debugPrint('🚫 Skipping download source (HTTP $code): ${res.$1.url}');
        }
      }

      // If validation filtered everything, pass all sources anyway to let Dio try
      final sourcesToOffer = validSources.isNotEmpty ? validSources : downloadSources;

      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

      if (sourcesToOffer.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No download sources available for this title. Please try again later.'))
        );
        return;
      }

      _showDownloadQualityDialog(sourcesToOffer);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing download links: $e'))
        );
      }
    }
  }

  void _showLoadingDownloadSourcesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Preparing download links...',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching and validating high-speed sources.',
              style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }


  void _showDownloadQualityDialog(List<StreamSource> sources) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        
        // Sort sources: Quality DESC, then Size DESC
        final sortedSources = List<StreamSource>.from(sources)..sort((a, b) {
           final aInt = int.tryParse(a.quality.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
           final bInt = int.tryParse(b.quality.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
           return bInt.compareTo(aInt);
        });

        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Download Quality',
                style: GoogleFonts.dmSerifDisplay(fontSize: 24, color: cs.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your preferred quality. Sources are optimized for speed.',
                style: GoogleFonts.dmSans(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: _buildQualityList(sortedSources, cs),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.speed_rounded, color: cs.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: Larger files usually offer better video and audio fidelity.',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
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

  Widget _buildQualityList(List<StreamSource> sources, ColorScheme cs) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: sources.length,
      padding: EdgeInsets.zero,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final source = sources[index];
        final sizeText = source.sizeText ?? 'Unknown size';
        
        return _sheetTrackTile(
          label: '${source.quality} · $sizeText',
          isActive: false,
          icon: CupertinoIcons.arrow_down_circle,
          cs: cs,
          onTap: () {
            Navigator.pop(context);
            _initiateDownload([source], 'DL'); // generic label for new endpoint
          },
        );
      },
    );
  }

  void _initiateDownload(List<StreamSource> sList, String label) async {
    _showDownloadStatusDialog(widget.item!, label);

    try {
      await _streamService.startDownload(sList, widget.item!, sourceLabel: label);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  void _showDownloadStatusDialog(MediaDetail item, String label) {
    bool timeoutReached = false;
    Timer? timeoutTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        timeoutTimer ??= Timer(const Duration(seconds: 15), () {
          if (mounted && Navigator.canPop(context)) {
            final download = _streamService.downloads.cast<DownloadItem?>().firstWhere(
              (d) => d?.mediaItem.id == item.id && d?.status == DownloadStatus.downloading,
              orElse: () => null,
            );
            if (download == null) {
              setState(() => timeoutReached = true);
            }
          }
        });

        return ValueListenableBuilder<int>(
          valueListenable: StreamingService.listChanged,
          builder: (context, _, __) {
            final download = _streamService.downloads.cast<DownloadItem?>().firstWhere(
              (d) => d?.mediaItem.id == item.id && d?.status != DownloadStatus.completed && d?.status != DownloadStatus.failed,
              orElse: () => null,
            );

            final cs = Theme.of(context).colorScheme;
            final isStarted = download != null;

            if (download != null && download.progress >= 0.999) {
              timeoutTimer?.cancel();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download completed successfully!'))
                  );
                }
              });
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: cs.surface.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    if (timeoutReached && !isStarted)
                      _buildTimeoutContent(cs)
                    else if (!isStarted)
                      const CircularProgressIndicator()
                    else
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: download.progress,
                              strokeWidth: 6,
                              backgroundColor: cs.primary.withValues(alpha: 0.1),
                            ),
                          ),
                          Text(
                            '${(download.progress * 100).toInt()}%',
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    if (!timeoutReached || isStarted) ...[
                      const SizedBox(height: 24),
                      Text(
                        isStarted ? 'Download Started!' : 'Searching for high-speed link...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isStarted 
                          ? 'The movie is saved to your library. You can close this and keep watching.'
                          : 'Verifying high-speed links...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ],
                    if (isStarted) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            timeoutTimer?.cancel();
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Close & Continue'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) => timeoutTimer?.cancel());
  }

  Widget _buildTimeoutContent(ColorScheme cs) {
    return Column(
      children: [
        Icon(Icons.report_problem_rounded, color: cs.error, size: 48),
        const SizedBox(height: 16),
        Text(
          'Server Not Responding',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'This link is taking too long. Please switch to other sources or try another quality.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Try Other Source'),
          ),
        ),
      ],
    );
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

    if (!_isStreamDone) {
      debugPrint('⏳ All known sources failed, but stream is still fetching. Waiting...');
      _handlingError = false;
      _selectedSource = null; // Ensures stream listener will pick up a new source if it appears
      return;
    }

    // FIX 6: Reset guard in the "all servers failed" path too —
    // was previously left true, permanently blocking future error handling.
    debugPrint('❌ All servers failed. Showing error screen.');
    _handlingError = false;
    if (mounted) {
      final msg = 'All available servers failed to load.\n${error.toString()}';
      setState(() {
        _loading = false;
        _error = true;
        _errorMsg = msg;
      });
      _showErrorDialog(msg);
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

    if (!skipHeaders && _selectedSource?.headers != null) {
      // Overwrite default headers with any dynamically provided headers from the source.
      headers.addAll(_selectedSource!.headers!);
    }

    // Stop and dispose old controller immediately to avoid background audio/video playing
    _videoPlayerController?.pause();
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    
    // Ensure we show loading state while pre-validating
    if (mounted && !_loading) {
      setState(() => _loading = true);
    }

    // FIX 7: Pre-validate URL with a HEAD request before handing to video_player.
    // This catches immediate 404s in ~8s instead of waiting for libmpv's
    // full internal timeout (which can be several minutes).
    final isLocal = url.startsWith('file://');
    final statusCode = isLocal 
        ? (await File(url.replaceFirst('file://', '')).exists() ? 200 : 404)
        : await _preValidateUrl(url, headers);
    
    if (!mounted) return;

    if (statusCode >= 400) {
      if (statusCode == 403 || statusCode == 401 || statusCode == 410) {
        debugPrint('🚫 Terminal error ($statusCode) for Server ${_selectedSource?.serverId}. Removing from priority list.');
        setState(() {
          _sources.removeWhere((s) => s.url == url);
        });
      }

      debugPrint(
        '❌ ${isLocal ? "Local file not found" : "Pre-validation failed ($statusCode) for Server ${_selectedSource?.serverId}"}',
      );
      _handleStreamError(
        isLocal ? 'Local video file missing or moved.' : 'URL pre-validation failed ($statusCode)',
        failedSource: _selectedSource,
      );
      return;
    }

    try {
      if (!mounted) return;
      
      if (isLocal) {
        _videoPlayerController = VideoPlayerController.file(File(url.replaceFirst('file:///', '')));
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: headers);
      }
      
      await _videoPlayerController!.initialize();
      _videoPlayerController!.play();
      
      try {
        _mediaInfo = _videoPlayerController!.getMediaInfo();
      } catch (_) {}

      if (mounted) {
        setState(() => _loading = false);
        _stopLoadingAnimation();

        // Seek once if we have a saved position
        if (!_hasSeeked && widget.item?.position != null) {
          _hasSeeked = true;
          await _videoPlayerController!.seekTo(Duration(milliseconds: widget.item!.position!));
        }
      }
    } catch (e) {
      debugPrint(
        '❌ Player init exception for Server ${_selectedSource?.serverId}: $e',
      );
      _handleStreamError(e, failedSource: _selectedSource);
    }
  }

  /// Validates a URL by sending a HEAD request first, then falling back to a
  /// partial GET. Returns an HTTP status code. Returns 200 for local files.
  /// Returns 200 even for 4xx Range-related codes (206, 416) since many CDNs
  /// block partial-content requests but serve the full file correctly.
  Future<int> _preValidateUrl(String url, Map<String, String> headers) async {
    if (url.startsWith('file://')) return 200;
    try {
      final client = Dio();
      client.options.connectTimeout = const Duration(seconds: 8);
      client.options.receiveTimeout = const Duration(seconds: 8);
      client.options.sendTimeout = const Duration(seconds: 8);

      final requestHeaders = Map<String, String>.from(headers);
      // Remove Range — many CDNs reject it and it's not needed for validation
      requestHeaders.remove('Range');
      requestHeaders.remove('range');

      final response = await client.head(
        url,
        options: Options(
          headers: requestHeaders,
          validateStatus: (s) => true, // Accept all codes — we check manually
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      final statusCode = response.statusCode ?? 500;
      final contentType = (response.headers.value('content-type') ?? '').toLowerCase();

      debugPrint('   Pre-validate HEAD: $statusCode | Type: $contentType | $url');

      // HTML response = error/login page, not a real stream
      if (contentType.contains('text/html')) {
        debugPrint('   ❌ Received HTML — not a valid stream source.');
        return 406;
      }

      // 405 = HEAD not allowed, but the file may be valid — try GET with no range
      if (statusCode == 405 || statusCode == 501) {
        debugPrint('   ⚠️  HEAD not supported ($statusCode), trying GET fallback...');
        return await _preValidateWithGet(url, requestHeaders, client);
      }

      // 2xx, 3xx = valid
      if (statusCode < 400) return 200;

      // 401/403/410 = definitively bad
      return statusCode;
    } catch (e) {
      debugPrint('   Pre-validate exception: $e');
      // On timeout/connection failure, assume source may still be valid (let player try it)
      return 200;
    }
  }

  /// Fallback GET-based validator when HEAD is rejected.
  Future<int> _preValidateWithGet(String url, Map<String, String> headers, Dio client) async {
    try {
      final response = await client.get(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          validateStatus: (s) => true,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );
      final statusCode = response.statusCode ?? 500;
      final contentType = (response.headers.value('content-type') ?? '').toLowerCase();

      // Close stream immediately — we only needed the headers
      try {
        final stream = response.data as ResponseBody?;
        await stream?.stream.drain();
      } catch (_) {}

      debugPrint('   Pre-validate GET fallback: $statusCode | Type: $contentType | $url');

      if (contentType.contains('text/html')) return 406;
      if (statusCode < 400) return 200;
      return statusCode;
    } catch (e) {
      debugPrint('   GET fallback exception: $e');
      return 200; // On error, let the player try
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _resetSystemUI();
    _videoPlayerController?.dispose();
    _stopLoadingAnimation();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _saveProgress() {
    if (widget.item == null || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    if (_videoPlayerController!.value.duration.inMilliseconds <= 0) return;

    final pos = _videoPlayerController!.value.position.inMilliseconds;
    final dur = _videoPlayerController!.value.duration.inMilliseconds;

    // If watched > 95%, we consider it finished and don't save progress
    // (or we save 0 so it's not in "Continue Watching" with 1 min left)
    final progress = pos / dur;
    final finalPos = progress > 0.95 ? 0 : pos;

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
        extraInfo: (widget.item!.mediaType == 'tv' &&
                widget.season != null &&
                widget.episode != null)
            ? 'S${widget.season} E${widget.episode}'
            : null,
        position: finalPos,
        duration: dur,
      ),
    );
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
              body: Stack(
                children: [
                  Center(child: _buildVideoContainer()),
// Remove _buildFloatingTopBar from over player in fullscreen
//                  Positioned(
//                    top: 0,
//                    left: 0,
//                    right: 0,
//                    child: SafeArea(child: _buildFloatingTopBar()),
//                  ),
                ],
              ),
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
                        color: cs.outlineVariant.withValues(alpha: 0.2),
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
// Remove _buildFloatingTopBar from over player
//                        Positioned(
//                          top: 0,
//                          left: 0,
//                          right: 0,
//                          child: SafeArea(child: _buildFloatingTopBar()),
//                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const NativeAdWidget(size: NativeAdSize.small), // First Ad (Small)
                            if (widget.item != null) _buildMovieInfo(),
                            const NativeAdWidget(size: NativeAdSize.medium), // Second Ad (Medium)
                            BannerAdWidget(), // Third Ad (Banner)
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
                icon: CupertinoIcons.chevron_back,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              Text(
                'Playback Settings',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 20,
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
                icon: CupertinoIcons.videocam_circle,
                title: 'Resolution',
                subtitle: 'Auto',
                onTap: _showVideoTrackSelection,
                cs: cs,
              ),
              _sidebarTile(
                icon: CupertinoIcons.layers_alt,
                title: 'Change Server',
                subtitle: _selectedSource?.source ?? 'Select Source',
                onTap: _showSourcePicker,
                cs: cs,
              ),
              _sidebarTile(
                icon: CupertinoIcons.globe,
                title: 'Language (Sources)',
                subtitle: _selectedLanguage ?? 'Original',
                onTap: _showLanguageSelection,
                cs: cs,
              ),
              _sidebarTile(
                icon: CupertinoIcons.waveform_circle,
                title: 'Regional Dubs (Server 2)',
                subtitle: 'Fetch dubbed versions',
                onTap: _fetchingDubs ? () {} : _fetchAndShowDubs,
                cs: cs,
              ),
              _sidebarTile(
                icon: CupertinoIcons.music_note_2,
                title: 'Audio Tracks (Internal)',
                subtitle: 'Internal embedded tracks',
                onTap: _showAudioSelection,
                cs: cs,
              ),
              _sidebarTile(
                icon: CupertinoIcons.arrow_down_circle,
                title: 'Download Video',
                subtitle: 'Save for offline viewing',
                onTap: _startDownload,
                cs: cs,
              ),
               Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                child: Text(
                  'SHORTCUTS',
                  style: GoogleFonts.dmSans(
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
          color: cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(color: cs.onSurfaceVariant, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDownloadProgressOverlay() {
    final curItem = widget.item;
    if (curItem == null) return const SizedBox.shrink();

    return ValueListenableBuilder<int>(
      valueListenable: StreamingService.listChanged,
      builder: (context, _, __) {
        final downloads = StreamingService.instance.downloads.where((d) => 
          d.mediaItem.id == curItem.id && 
          (d.status == DownloadStatus.downloading || d.status == DownloadStatus.paused)
        ).toList();

        if (downloads.isEmpty) return const SizedBox.shrink();
        
        final download = downloads.first;
        return Container(
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (download.status == DownloadStatus.downloading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(CupertinoIcons.pause_fill, size: 14, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                '${(download.progress * 100).toInt()}%',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
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
          const Spacer(),
          _buildDownloadProgressOverlay(),
          const Spacer(),
          const SizedBox(width: 48), // Spacer to balance the back button
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
    if (_error) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Icon(
            CupertinoIcons.play_rectangle_fill,
            color: Colors.white.withValues(alpha: 0.1),
            size: 64,
          ),
        ),
      );
    }

    return Stack(
      children: [
        if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)
          FvpCustomControls(
            controller: _videoPlayerController!,
            onFullscreenToggle: _toggleFullscreen,
            onShowSettings: _showSettingsSheet,
            topBar: _buildFloatingTopBar(),
          )
        else
          Container(color: Colors.black),
        if (_fetchingDubs) _buildFetchingOverlay(),
      ],
    );
  }

  Widget _buildFetchingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Fetching regional dubs (Server 2)...',
              style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Sheets ───────────────────────────────────────────────────────────

  void _showSettingsSheet() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : cs.surface.withValues(alpha: 0.8),
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
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sheetOption(
                      icon: CupertinoIcons.speedometer,
                      label: 'Playback Speed (${_videoPlayerController?.value.playbackSpeed ?? 1.0}x)',
                      cs: cs,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSpeedSelector();
                      },
                    ),
                    const SizedBox(height: 8),
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
                    if (widget.item?.mediaType == 'tv') ...[
                      const SizedBox(height: 8),
                      _sheetOption(
                        icon: CupertinoIcons.list_bullet,
                        label: 'Episodes',
                        cs: cs,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showEpisodeSelector();
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    _sheetOption(
                      icon: CupertinoIcons.arrow_down_circle,
                      label: 'Download Video',
                      cs: cs,
                      onTap: () {
                        Navigator.pop(ctx);
                        _startDownload();
                      },
                    ),
                    const SizedBox(height: 8),
                    _sheetOption(
                      icon: CupertinoIcons.music_note_2,
                      label: 'Audio Tracks (Internal)',
                      cs: cs,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAudioSelection();
                      },
                    ),
                    const SizedBox(height: 8),
                    _sheetOption(
                      icon: CupertinoIcons.globe,
                      label: 'Change Language (Dubs)',
                      cs: cs,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showLanguageSelection();
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

  void _showSpeedSelector() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : cs.surface.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: _dragHandle()),
                const SizedBox(height: 20),
                Text(
                  'Select Playback Speed',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: speeds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final s = speeds[index];
                      final isActive = _videoPlayerController?.value.playbackSpeed == s;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _sheetTrackTile(
                          label: '${s}x',
                          isActive: isActive,
                          icon: CupertinoIcons.speedometer,
                          cs: cs,
                          onTap: () {
                            _videoPlayerController?.setPlaybackSpeed(s);
                            Navigator.pop(ctx);
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
    );
  }

  Future<void> _fetchAndShowDubs() async {
    if (widget.item == null) return;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const M3Loading(size: 48),
              const SizedBox(height: 24),
              Text(
                'Fetching regional dubs...',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    try {
      final dubs = await _streamService.getSpecificServerSources(
        widget.item!.mediaType,
        widget.item!.id,
        2, // Server 2 is for Dubs
        season: widget.season,
        episode: widget.episode,
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Remove loading dialog

      if (dubs.isNotEmpty) {
        setState(() {
          for (var d in dubs) {
            if (!_sources.any((s) => s.url == d.url)) {
              _sources.add(d);
            }
          }
        });
      }
      _showDubsMenu(dubs);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch dubs: $e')),
        );
      }
    }
  }

  void _showDubsMenu(List<StreamSource> sources) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredSources = sources.where((s) => s.serverId == 2).toList();
    if (filteredSources.isEmpty) {
       // If somehow called with no server 2 sources, we should not show an empty menu
       return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : cs.surface.withValues(alpha: 0.8),
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
                      'Available Dubs (Server 2)',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredSources.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final s = filteredSources[index];
                          String label = s.language ?? 'Unknown';
                          final isCurrent = _selectedSource?.url == s.url;

                          return _sheetTrackTile(
                            label: '$label (${s.quality})',
                            isActive: isCurrent,
                            icon: CupertinoIcons.waveform_path,
                            cs: cs,
                            onTap: () {
                              Navigator.pop(ctx);
                              if (!isCurrent) {
                                _applyNewSource(s);
                              }
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

  void _applyNewSource(StreamSource source) async {
    final pos = _videoPlayerController?.value.position ?? Duration.zero;
    setState(() {
      _selectedSource = source;
      _selectedLanguage = source.language;
      _loading = true;
      // Ensure the newly selected source (e.g. a dub) is in the sources list
      if (!_sources.any((s) => s.url == source.url)) {
        _sources.add(source);
      }
    });
    
    await _initPlayer(source.url);
    if (_videoPlayerController != null) {
      await _videoPlayerController!.seekTo(pos);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showLanguageSelection() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Distinct languages available in sources, plus "Original" (null)
    final languages = _sources
        .map((s) => s.language)
        .whereType<String>()
        .toSet()
        .toList();
    
    // Add "Original" as the first option
    languages.insert(0, 'Original');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : cs.surface.withValues(alpha: 0.8),
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
                      'Select Language',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: languages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final lang = languages[index];
                          final actualLang = lang == 'Original' ? null : lang;
                          final isActive = _selectedLanguage == actualLang;
                          
                          return _sheetTrackTile(
                            label: lang,
                            isActive: isActive,
                            icon: CupertinoIcons.globe,
                            cs: cs,
                            onTap: () {
                              Navigator.pop(ctx);
                              if (!isActive) {
                                _changeLanguage(actualLang);
                              }
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

  void _changeLanguage(String? language) async {
    debugPrint('🌐 Changing language to: ${language ?? "Original"}');
    
    // Find best source matching new language
    final nextSource = _sources.cast<StreamSource?>().firstWhere(
      (s) => s != null && !_failedCDNs.contains(_getCDN(s.url)) && s.language == language,
      orElse: () => _sources.cast<StreamSource?>().firstWhere(
        (s) => s != null && !_failedCDNs.contains(_getCDN(s.url)),
        orElse: () => null,
      ),
    );

    if (nextSource != null) {
      if (mounted) {
        setState(() {
          _selectedLanguage = language;
          _selectedSource = nextSource;
          _loading = true;
          _error = false;
        });
      }
      _initPlayer(nextSource.url);
    }
  }

  void _showAudioSelection() {
    if (_mediaInfo == null || _mediaInfo.audio == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No internal audio tracks detected.')));
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioTracks = _mediaInfo.audio as List;
    final activeTracks = _videoPlayerController?.getActiveAudioTracks() ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : cs.surface.withValues(alpha: 0.8),
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
                      'Internal Audio Tracks',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: audioTracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final track = audioTracks[index];
                          final trackId = track.index ?? index;
                          final lang = track.metadata?['language'] ?? 'Track ${index + 1}';
                          final isActive = activeTracks.contains(trackId);
                          
                          return _sheetTrackTile(
                            label: '$lang (${track.codec ?? "Unknown"})',
                            isActive: isActive,
                            icon: CupertinoIcons.waveform,
                            cs: cs,
                            onTap: () {
                              _videoPlayerController?.setAudioTracks([trackId]);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Switched to $lang')),
                              );
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
    if (_mediaInfo == null || _mediaInfo.video == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No internal video tracks detected.')));
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final videoTracks = _mediaInfo.video as List;
    final activeTracks = _videoPlayerController?.getActiveVideoTracks() ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : cs.surface.withValues(alpha: 0.8),
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
                      'Internal Video Tracks',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: videoTracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final track = videoTracks[index];
                          final trackId = track.index ?? index;
                          final isActive = activeTracks.contains(trackId);
                          final codec = track.codec ?? "Unknown";
                          
                          return _sheetTrackTile(
                            label: 'Track $index ($codec)',
                            isActive: isActive,
                            icon: CupertinoIcons.videocam,
                            cs: cs,
                            onTap: () {
                              _videoPlayerController?.setVideoTracks([trackId]);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Switched to Video Track $index')),
                              );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : cs.surface.withValues(alpha: 0.8),
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
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          CupertinoIcons.sparkles,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select Quality',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${availableSources.length} sources',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (availableSources.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          _loading ? 'Searching for sources...' : 'No available sources found',
                          style: GoogleFonts.dmSans(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: availableSources.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = availableSources[i];
                        final active = s == _selectedSource;
                        // Determine quality icon
                        IconData qualIcon = CupertinoIcons.videocam_fill;
                        final q = s.quality.toLowerCase();
                        if (q.contains('4k') || q.contains('2160')) {
                          qualIcon = CupertinoIcons.star_circle_fill;
                        } else if (q.contains('1080')) {
                          qualIcon = CupertinoIcons.check_mark_circled_solid;
                        } else if (q.contains('720')) {
                          qualIcon = CupertinoIcons.tv_fill;
                        } else if (q.contains('480')) {
                          qualIcon = Icons.sd_rounded;
                        }

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: active
                                ? cs.primary.withValues(alpha: 0.15)
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active
                                  ? cs.primary.withValues(alpha: 0.5)
                                  : cs.outlineVariant.withValues(alpha: 0.4),
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
                                    ? cs.primary.withValues(alpha: 0.2)
                                    : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                qualIcon,
                                color: active
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              s.quality,
                              style: GoogleFonts.dmSans(
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
                              style: GoogleFonts.dmSans(
                                color: active
                                    ? cs.primary.withValues(alpha: 0.7)
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
                                      color: cs.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.checkmark_alt,
                                          size: 14,
                                          color: cs.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Playing',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11,
                                            color: cs.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                            onTap: () async {
                              Navigator.pop(ctx);
                              if (!active) {
                                debugPrint('\n🔀 Manual source switch → $s');
                                // Allow the bottom sheet dismissal animation to complete
                                // before reinitializing the player to prevent context crashes.
                                await Future.delayed(const Duration(milliseconds: 150));
                                if (!mounted) return;
                                setState(() {
                                  _selectedSource = s;
                                  _handlingError = false; // Reset guard for clean switch
                                  _failedCDNs.remove(_getCDN(s.url)); // Re-allow this CDN
                                  _loading = true;
                                  _error = false;
                                });
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
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
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
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? CupertinoIcons.checkmark_circle_fill : icon,
              color: isActive
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Active',
                  style: GoogleFonts.dmSans(
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
    return Container(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
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
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSerifDisplay(
                  color: cs.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showErrorDialog(String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: cs.onSurface.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -12,
                    right: -12,
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        CupertinoIcons.clear_circled_solid,
                        color: cs.onSurface.withValues(alpha: 0.4),
                        size: 30,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: cs.error,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Playback Interrupted',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _loadMovieStreams();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Try Again',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                style: GoogleFonts.dmSerifDisplay(
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
                  style: GoogleFonts.dmSans(
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
                  _infoBadge(item.year, CupertinoIcons.calendar),
                  _infoBadge(
                    item.ratingStr,
                    CupertinoIcons.star_fill,
                    iconColor: Colors.amber,
                  ),
                  if (item.runtime != null)
                    _infoBadge('${item.runtime}m', CupertinoIcons.time),
                ],
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 24),
              _buildActionRow().animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'SYNOPSIS',
            style: GoogleFonts.dmSans(
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
            style: GoogleFonts.dmSans(
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
              separatorBuilder: (_, _) => const SizedBox(width: 20),
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
                              CupertinoIcons.person_fill,
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
                        style: GoogleFonts.dmSans(
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
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _actionChip(
            icon: CupertinoIcons.chevron_back,
            label: 'Back',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          _actionChip(
            icon: CupertinoIcons.settings,
            label: 'Settings',
            onTap: _showSettingsSheet,
          ),
          const SizedBox(width: 8),
          _actionChip(
            icon: CupertinoIcons.waveform_circle,
            label: 'Dubs',
            onTap: _fetchAndShowDubs,
          ),
          if (widget.item?.mediaType == 'tv') ...[
            const SizedBox(width: 8),
            _actionChip(
              icon: CupertinoIcons.list_bullet,
              label: 'Episodes',
              onTap: _showEpisodeSelector,
            ),
          ],
          const SizedBox(width: 8),
          _actionChip(
            icon: CupertinoIcons.arrow_down_to_line,
            label: 'Download',
            onTap: _startDownload,
          ),
          const SizedBox(width: 8),
          _actionChip(
            icon: CupertinoIcons.share,
            label: 'Share',
            onTap: () {
              if (widget.item == null) return;
              final url = '${ApiService.websiteUrl}/details/${widget.item!.mediaType}/${widget.item!.id}';
              Share.share(
                'Check out "${widget.item!.title}" on StreamFlix!\n\nWatch here: $url',
                subject: 'Share ${widget.item!.title}',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: cs.onSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEpisodeSelector() {
    if (widget.item == null || widget.item!.mediaType != 'tv') return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlayerEpisodeSelectorSheet(
        tvDetail: widget.item!,
        currentSeason: widget.season,
        currentEpisode: widget.episode,
        onEpisodeSelected: (s, e) {
          // Restart player with new episode
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                item: widget.item,
                season: s,
                episode: e,
              ),
            ),
          );
        },
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
      onInvoke: (_) => setState(() {
        if (_videoPlayerController?.value.isPlaying == true) {
          _videoPlayerController?.pause();
        } else {
          _videoPlayerController?.play();
        }
      }),
    ),
    _ToggleFullscreenIntent: CallbackAction<_ToggleFullscreenIntent>(
      onInvoke: (_) => _toggleFullscreen(),
    ),
    _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(
      onInvoke: (_) {
        final currentPos = _videoPlayerController?.value.position ?? Duration.zero;
        _videoPlayerController?.fastSeekTo(currentPos + const Duration(seconds: 10));
        return null;
      },
    ),
    _SeekBackwardIntent: CallbackAction<_SeekBackwardIntent>(
      onInvoke: (_) {
        final currentPos = _videoPlayerController?.value.position ?? Duration.zero;
        _videoPlayerController?.fastSeekTo(currentPos - const Duration(seconds: 10));
        return null;
      },
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
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Text(
              keyLabel,
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            action,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
// ── Private Widgets for Player Episode Selection ────────────────────────────

class _PlayerEpisodeSelectorSheet extends StatefulWidget {
  final MediaDetail tvDetail;
  final int? currentSeason;
  final int? currentEpisode;
  final void Function(int season, int episode)? onEpisodeSelected;

  const _PlayerEpisodeSelectorSheet({
    required this.tvDetail,
    this.currentSeason,
    this.currentEpisode,
    this.onEpisodeSelected,
  });

  @override
  State<_PlayerEpisodeSelectorSheet> createState() =>
      _PlayerEpisodeSelectorSheetState();
}

class _PlayerEpisodeSelectorSheetState
    extends State<_PlayerEpisodeSelectorSheet> {
  late TvSeason _selectedSeason;
  List<TvEpisode> _episodes = [];
  bool _loading = false;
  final _api = ApiService.instance;

  @override
  void initState() {
    super.initState();
    // Default to current season or first season
    _selectedSeason = widget.tvDetail.seasons.firstWhere(
      (s) => s.seasonNumber == (widget.currentSeason ?? 1),
      orElse: () => widget.tvDetail.seasons.firstWhere(
        (s) => s.seasonNumber > 0,
        orElse: () => widget.tvDetail.seasons.first,
      ),
    );
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _loading = true);
    final season = await _api.getTvSeasonDetail(
        widget.tvDetail.id, _selectedSeason.seasonNumber);
    if (mounted) {
      setState(() {
        _episodes = season?.episodes ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F0F) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            width: 1),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
            child: Row(
              children: [
                Text(
                  'Episodes',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 28,
                    color: cs.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TvSeason>(
                      value: _selectedSeason,
                      dropdownColor: isDark ? const Color(0xFF1A1A1A) : cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      icon: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(CupertinoIcons.chevron_down, size: 14),
                      ),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      items: widget.tvDetail.seasons
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s.name)))
                          .toList(),
                      onChanged: (s) {
                        if (s != null) {
                          setState(() => _selectedSeason = s);
                          _loadEpisodes();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: M3Loading(message: 'Loading episodes...'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _episodes.length,
                    itemBuilder: (_, i) => _PlayerEpisodeTile(
                      episode: _episodes[i],
                      isCurrent: _episodes[i].episodeNumber ==
                              widget.currentEpisode &&
                          _episodes[i].seasonNumber == widget.currentSeason,
                      onTap: () {
                        if (widget.onEpisodeSelected != null) {
                          Navigator.pop(context);
                          widget.onEpisodeSelected!(
                              _episodes[i].seasonNumber, _episodes[i].episodeNumber);
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlayerEpisodeTile extends StatelessWidget {
  final TvEpisode episode;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlayerEpisodeTile({
    required this.episode,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? cs.primaryContainer.withValues(alpha: 0.3)
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? cs.primary.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: episode.fullStillUrl,
                  width: 100,
                  height: 60,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 100,
                    height: 60,
                    color: cs.surfaceContainerHighest,
                    child: Icon(CupertinoIcons.film,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episode ${episode.episodeNumber}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      episode.name,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Icon(CupertinoIcons.play_circle_fill, color: cs.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
