import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // We fallback to external browser on Linux, but Windows and Mac are supported natively by flutter_inappwebview
  bool get _isLinux => !kIsWeb && Platform.isLinux;

  @override
  void initState() {
    super.initState();
    // Auto-rotate to landscape if possible, or just keep it flexible
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLinux && webViewController != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => webViewController!.reload(),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLinux) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videogame_asset, size: 80, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Games play best in your browser on desktop.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(widget.url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Play Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
            child: CircularProgressIndicator(color: Color(0xFFE50914)),
          ),
      ],
    );
  }
}
