import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/music_service.dart';
import '../widgets/mini_player_wrapper.dart';

class GameViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const GameViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<GameViewScreen> createState() => _GameViewScreenState();
}

class _GameViewScreenState extends State<GameViewScreen> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;

  bool get _isLinux => !kIsWeb && Platform.isLinux;

  @override
  void initState() {
    MusicService.instance.stopMusic();
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniPlayerWrapper(
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        navigationBar: CupertinoNavigationBar(
          transitionBetweenRoutes: false,
          middle: Text(
            widget.title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: CupertinoColors.white),
          ),
          backgroundColor: CupertinoColors.black.withValues(alpha: 0.8),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.back, color: CupertinoColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          trailing: !_isLinux && webViewController != null
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.refresh, color: CupertinoColors.white),
                  onPressed: () => webViewController!.reload(),
                )
              : null,
        ),
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLinux) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.gamecontroller, size: 80, color: CupertinoColors.systemGrey),
            const SizedBox(height: 16),
            const Text(
              'Games play best in your browser on desktop.',
              style: TextStyle(color: CupertinoColors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              onPressed: () => launchUrl(
                Uri.parse(widget.url),
                mode: LaunchMode.externalApplication,
              ),
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(30),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.arrow_up_right_square, size: 20),
                  const SizedBox(width: 8),
                  Text('Play Now', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
            builtInZoomControls: false,
            displayZoomControls: false,
            supportMultipleWindows: false,
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          onLoadStart: (controller, url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onLoadStop: (controller, url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onProgressChanged: (controller, progress) {
            if (progress == 100 && mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
        if (_isLoading)
          const Center(
            child: CupertinoActivityIndicator(radius: 15, color: Color(0xFFE50914)),
          ),
      ],
    );
  }
}



