import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';

class FvpCustomControls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onFullscreenToggle;
  final Widget? topBar;

  const FvpCustomControls({
    super.key,
    required this.controller,
    required this.onFullscreenToggle,
    this.topBar,
  });

  @override
  State<FvpCustomControls> createState() => _FvpCustomControlsState();
}

class _FvpCustomControlsState extends State<FvpCustomControls> {
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    widget.controller.addListener(_videoListener);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying && !_isDragging) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _playPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _startHideTimer();
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
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Video
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio > 0
                  ? widget.controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(widget.controller),
            ),
          ),
          
          if (_showControls) ...[
            // Overlay gradient for better visibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            
            // Top Bar
            if (widget.topBar != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: widget.topBar!),
              ),
              
            // Center Controls
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconButton(
                    icon: CupertinoIcons.gobackward_10,
                    size: 28,
                    onPressed: () {
                      final pos = widget.controller.value.position;
                      widget.controller.seekTo(pos - const Duration(seconds: 10));
                      _startHideTimer();
                    },
                  ),
                  const SizedBox(width: 48),
                  _IconButton(
                    icon: widget.controller.value.isPlaying
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    size: 48,
                    onPressed: _playPause,
                  ),
                  const SizedBox(width: 48),
                  _IconButton(
                    icon: CupertinoIcons.goforward_10,
                    size: 28,
                    onPressed: () {
                      final pos = widget.controller.value.position;
                      widget.controller.seekTo(pos + const Duration(seconds: 10));
                      _startHideTimer();
                    },
                  ),
                ],
              ),
            ),
            
            // Bottom Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time & Fullscreen Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _formatDuration(widget.controller.value.position),
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "|",
                            style: TextStyle(color: Colors.white38, fontSize: 14),
                          ),
                        ),
                        Text(
                          _formatDuration(widget.controller.value.duration),
                          style: GoogleFonts.dmSans(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.fullscreen,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: widget.onFullscreenToggle,
                        ),
                      ],
                    ),
                  ),
                  
                  // Progress Bar
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                        pressedElevation: 0,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: Colors.red,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.red,
                      trackShape: const _FullWidthTrackShape(),
                    ),
                    child: SizedBox(
                      height: 12,
                      child: Slider(
                        value: widget.controller.value.position.inMilliseconds.toDouble(),
                        min: 0.0,
                        max: widget.controller.value.duration.inMilliseconds.toDouble() > 0
                            ? widget.controller.value.duration.inMilliseconds.toDouble()
                            : 1.0,
                        onChangeStart: (_) {
                          _isDragging = true;
                          _hideTimer?.cancel();
                        },
                        onChanged: (v) {
                          widget.controller.seekTo(Duration(milliseconds: v.toInt()));
                        },
                        onChangeEnd: (_) {
                          _isDragging = false;
                          _startHideTimer();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _IconButton({
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        iconSize: size,
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _FullWidthTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthTrackShape();
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
