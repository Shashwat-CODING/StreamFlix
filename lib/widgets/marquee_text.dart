import 'dart:async';
import 'package:flutter/cupertino.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final Duration scrollDuration;
  final Duration pauseDuration;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
    this.scrollDuration = const Duration(seconds: 8),
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  Timer? _timer;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopScrolling();
      _scrollController.jumpTo(0.0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
    }
  }

  void _startScrolling() {
    if (!mounted) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      // No scrolling needed if text fits
      return;
    }

    _isScrolling = true;
    _runScrollCycle();
  }

  void _runScrollCycle() async {
    if (!mounted || !_isScrolling) return;

    // Wait at the beginning
    await Future.delayed(widget.pauseDuration);
    if (!mounted || !_isScrolling) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    // Scroll to the end
    await _scrollController.animateTo(
      maxScroll,
      duration: widget.scrollDuration,
      curve: Curves.linear,
    );
    if (!mounted || !_isScrolling) return;

    // Wait at the end
    await Future.delayed(widget.pauseDuration);
    if (!mounted || !_isScrolling) return;

    // Instantly jump back or scroll back
    await _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    );

    // Repeat cycle
    _runScrollCycle();
  }

  void _stopScrolling() {
    _isScrolling = false;
    _timer?.cancel();
  }

  @override
  void dispose() {
    _stopScrolling();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), // Scroll animated programmatically
      child: Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );
  }
}
