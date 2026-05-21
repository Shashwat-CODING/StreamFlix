import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Colors, Slider, CircularProgressIndicator, Theme, Brightness, SliderTheme, SliderThemeData, RoundSliderThumbShape, RoundSliderOverlayShape, Material, MaterialType;
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';


class FvpCustomControls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onFullscreenToggle;
  final VoidCallback? onShowSettings;
  final Widget? topBar;
  final String? mediaId;
  final String? mediaType;

  const FvpCustomControls({
    super.key,
    required this.controller,
    required this.onFullscreenToggle,
    this.onShowSettings,
    this.topBar,
    this.mediaId,
    this.mediaType,
  });

  @override
  State<FvpCustomControls> createState() => _FvpCustomControlsState();
}

class _FvpCustomControlsState extends State<FvpCustomControls> {
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isDragging = false;
  double _latestVolume = 1.0;
  final TransformationController _transformationController = TransformationController();
  bool _isZoomedToFill = false;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    widget.controller.addListener(_videoListener);
    _latestVolume = widget.controller.value.volume;

  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_videoListener);
    _transformationController.dispose();
    super.dispose();
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.controller.value.isPlaying && !_isDragging) {
        setState(() => _showControls = false);
      }
    });
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    setState(() {
      _showControls = true;
    });
    _startHideTimer();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _playPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      if (widget.controller.value.position >= widget.controller.value.duration) {
        widget.controller.seekTo(Duration.zero);
      }
      widget.controller.play();
    }
    _cancelAndRestartTimer();
  }

  void _skipBack() {
    final pos = widget.controller.value.position;
    final newPos = pos - const Duration(seconds: 15);
    widget.controller.seekTo(newPos);
    _cancelAndRestartTimer();
  }

  void _skipForward() {
    final pos = widget.controller.value.position;
    final newPos = pos + const Duration(seconds: 15);
    widget.controller.seekTo(newPos);
    _cancelAndRestartTimer();
  }

  void _toggleMute() {
    if (widget.controller.value.volume == 0) {
      widget.controller.setVolume(_latestVolume > 0 ? _latestVolume : 1.0);
    } else {
      _latestVolume = widget.controller.value.volume;
      widget.controller.setVolume(0.0);
    }
    _cancelAndRestartTimer();
  }

  void _toggleZoomFill() {
    setState(() {
      _isZoomedToFill = !_isZoomedToFill;
      if (!_isZoomedToFill) {
        _transformationController.value = Matrix4.identity();
      }
    });
    _cancelAndRestartTimer();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final bool isFinished = widget.controller.value.position >= widget.controller.value.duration && widget.controller.value.duration.inSeconds > 0;
    
    return MouseRegion(
      onHover: (_) => _cancelAndRestartTimer(),
      child: GestureDetector(
        onTap: _toggleControls,
        onDoubleTap: _toggleZoomFill,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Layer
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final videoRatio = widget.controller.value.aspectRatio > 0 ? widget.controller.value.aspectRatio : 16/9;
                  final containerRatio = constraints.maxWidth / constraints.maxHeight;
                  
                  // Calculate scale to fill screen if zoomed
                  double fillScale = 1.0;
                  if (_isZoomedToFill) {
                    if (videoRatio > containerRatio) {
                      fillScale = videoRatio / containerRatio;
                    } else {
                      fillScale = containerRatio / videoRatio;
                    }
                  }

                  return InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Transform.scale(
                      scale: fillScale,
                      child: AspectRatio(
                        aspectRatio: videoRatio,
                        child: VideoPlayer(widget.controller),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Buffering Indicator
            if (widget.controller.value.isBuffering)
              const Center(
                child: CupertinoActivityIndicator(radius: 20, color: CupertinoColors.white),
              ),
            
            // Hit Area Center Play Button
            if (_showControls && (!widget.controller.value.isPlaying || isFinished))
              Center(
                child: GestureDetector(
                  onTap: _playPause,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: CupertinoColors.white.withValues(alpha: 0.1), width: 0.5),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Icon(
                          isFinished ? Icons.replay : (widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                          color: CupertinoColors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Controls Overlay
            IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CupertinoColors.black.withValues(alpha: 0.6),
                        CupertinoColors.transparent,
                        CupertinoColors.transparent,
                        CupertinoColors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.0, 0.2, 0.8, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Top Bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                if (widget.topBar != null) Expanded(child: widget.topBar!),
                                const Spacer(),
                                _buildTopBarButton(
                                  icon: _isZoomedToFill ? CupertinoIcons.zoom_out : CupertinoIcons.zoom_in,
                                  onPressed: _toggleZoomFill,
                                ),
                                const SizedBox(width: 8),
                                _buildTopBarButton(
                                  icon: widget.controller.value.volume > 0 ? CupertinoIcons.volume_up : CupertinoIcons.volume_off,
                                  onPressed: _toggleMute,
                                ),
                                const SizedBox(width: 8),
                                _buildTopBarButton(
                                  icon: CupertinoIcons.fullscreen,
                                  onPressed: widget.onFullscreenToggle,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom Bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Integrated Progress Bar
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: CupertinoVideoProgressBar(
                                    controller: widget.controller,
                                    onDragStart: () {
                                      setState(() => _isDragging = true);
                                      _hideTimer?.cancel();
                                    },
                                    onDragEnd: () {
                                      setState(() => _isDragging = false);
                                      _startHideTimer();
                                    },
                                    onSeek: null,
                                  ),
                                ),
                                Row(
                                  children: [
                                    _buildControlIcon(
                                      icon: CupertinoIcons.gobackward_15,
                                      onPressed: _skipBack,
                                    ),
                                    _buildControlIcon(
                                      icon: widget.controller.value.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                      onPressed: _playPause,
                                      size: 32,
                                    ),
                                    _buildControlIcon(
                                      icon: CupertinoIcons.goforward_15,
                                      onPressed: _skipForward,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _formatDuration(widget.controller.value.position),
                                      style: GoogleFonts.outfit(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      ' / ${_formatDuration(widget.controller.value.duration)}',
                                      style: GoogleFonts.outfit(color: CupertinoColors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    const Spacer(),
                                    _buildControlIcon(
                                      icon: Icons.settings,
                                      onPressed: () {
                                        if (widget.onShowSettings != null) widget.onShowSettings!();
                                      },
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildTopBarButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.all(12),
        onPressed: onPressed,
        child: Icon(icon, color: CupertinoColors.white, size: 20),
      ),
    );
  }

  Widget _buildControlIcon({required IconData icon, required VoidCallback onPressed, double size = 26}) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onPressed: onPressed,
      child: Icon(icon, color: CupertinoColors.white, size: size),
    );
  }
}

class CupertinoVideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final Function(Duration)? onSeek;

  const CupertinoVideoProgressBar({
    super.key,
    required this.controller,
    this.onDragStart,
    this.onDragEnd,
    this.onSeek,
  });

  @override
  State<CupertinoVideoProgressBar> createState() => _CupertinoVideoProgressBarState();
}

class _CupertinoVideoProgressBarState extends State<CupertinoVideoProgressBar> {
  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final duration = widget.controller.value.duration.inMilliseconds.toDouble();
    final position = widget.controller.value.position.inMilliseconds.toDouble();
    
    return Container(
      height: 32,
      width: double.infinity,
      child: Material(
        type: MaterialType.transparency,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: theme.primaryColor,
            inactiveTrackColor: CupertinoColors.white.withValues(alpha: 0.2),
            thumbColor: CupertinoColors.white,
          ),
          child: Slider(
            value: position.clamp(0, duration > 0 ? duration : 1),
            min: 0.0,
            max: duration > 0 ? duration : 1.0,
            onChanged: (v) {
              widget.onDragStart?.call();
              final d = Duration(milliseconds: v.toInt());
              widget.controller.seekTo(d);
              widget.onSeek?.call(d);
            },
            onChangeEnd: (v) {
              widget.onDragEnd?.call();
            },
          ),
        ),
      ),
    );
  }
}
