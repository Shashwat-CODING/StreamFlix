import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/detail_screen.dart';
import '../screens/search_screen.dart';
import '../widgets/m3_loading.dart';
import '../main.dart';
import '../screens/onboarding_screen.dart';


class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Function(int)? _onTabChange;

  // Stores the initial link if the navigator wasn't ready yet
  Uri? _pendingUri;
  
  // Guard against duplicate/looping triggers
  Uri? _lastHandledUri;
  DateTime? _lastHandledTime;
  bool _isProcessing = false;

  void init({Function(int)? onTabChange}) {
    _onTabChange = onTabChange;

    // Cancel any previous subscription
    _linkSubscription?.cancel();

    // Process any pending link that arrived before the navigator was ready
    if (_pendingUri != null) {
      final uri = _pendingUri!;
      _pendingUri = null;
      debugPrint('DeepLink: Processing pending URI: $uri');
      _handleUri(uri);
    }

    // Check initial link — this handles cold-start
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('DeepLink: Initial link received: $uri');
        _handleUri(uri);
      }
    });

    // Listen for incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('DeepLink: Stream link received: $uri');
      _handleUri(uri);
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  String? _lastConfigUrl;

  void _handleUri(Uri uri) async {
    // 0. Guard against duplication and recursive loops
    final now = DateTime.now();
    if (_lastHandledUri == uri && 
        _lastHandledTime != null && 
        now.difference(_lastHandledTime!).inMilliseconds < 1500) {
      debugPrint('DeepLink: Skipping duplicate link within 1.5s: $uri');
      return;
    }
    if (_isProcessing) {
      debugPrint('DeepLink: Busy processing another link, skipping: $uri');
      return;
    }
    
    _isProcessing = true;
    _lastHandledUri = uri;
    _lastHandledTime = now;

    final scheme = uri.scheme;
    final host = uri.host;
    final path = uri.path;
    final params = uri.queryParameters;

    try {
      debugPrint('DeepLink received: scheme=$scheme, host=$host, path=$path, params=$params');

      // Normalize: custom scheme (drishya://host/path) puts first segment in 'host'
      // HTTPS links put everything in 'path'.
      String fullPath = (host.isNotEmpty && scheme == 'drishya')
          ? '/$host$path'
          : path;

      // Standardize path (remove trailing slash, ensure leading slash)
      if (fullPath.endsWith('/') && fullPath.length > 1) {
        fullPath = fullPath.substring(0, fullPath.length - 1);
      }
      if (!fullPath.startsWith('/')) {
        fullPath = '/$fullPath';
      }

      debugPrint('DeepLink normalized path: $fullPath');

      // 1. Config Page: /config?base=... — works even when NOT configured
      if (fullPath.startsWith('/config')) {
        final base = params['base'] ?? params['url'];
        if (base != null && base.isNotEmpty) {
          final fullUrl = uri.toString();
          if (_lastConfigUrl == fullUrl) return;
          _lastConfigUrl = fullUrl;

          // Wait for navigator
          await _waitForNavigator();
          if (navigatorKey.currentState == null) {
            debugPrint('DeepLink Error: Navigator not ready for config link');
            return;
          }

          _showLoadingOverlay(message: 'Validating Backend...');
          final isValid = await ApiService.instance.validateBaseUrl(base);
          _hideLoadingOverlay();

          if (isValid) {
            await ApiService.instance.setBaseUrl(base);
            _showSnackBar('Backend link successful!', isError: false);
            _refreshApp();
          } else {
            debugPrint('DeepLink: Config URL validation failed for: $base');
            _showSnackBar('Invalid or unreachable backend server.', isError: true);
          }
          return;
        }
      }

      // 2. Ensure navigator is ready for all other routes
      await _waitForNavigator();

      if (navigatorKey.currentState == null) {
        debugPrint('DeepLink Error: Navigator not ready after waiting');
        return;
      }

      // 3. If app is not configured yet, store the link and wait
      //    The link will be replayed once init() is called from MainNavigation
      if (!ApiService.instance.isConfigured) {
        debugPrint('DeepLink: App not configured, storing pending URI: $uri');
        _pendingUri = uri;
        return;
      }

      // 4. Details Page: /details/[type]/[id]
      if (fullPath.startsWith('/details/')) {
        final segments = fullPath.split('/').where((s) => s.isNotEmpty).toList();
        // Expecting: ['details', type, id]
        if (segments.length >= 3) {
          final type = segments[1];
          final id = int.tryParse(segments[2]);
          if (id != null && (type == 'movie' || type == 'tv')) {
            debugPrint('DeepLink: Navigating to detail: type=$type, id=$id');
            await _navigateToDetails(id, type);
          } else {
            debugPrint('DeepLink Error: Invalid details path. type=$type, id=${segments[2]}');
          }
        } else {
          debugPrint('DeepLink Error: Details path has too few segments: $fullPath');
        }
      }
      // 5. Live TV tab: /live-tv
      else if (fullPath == '/live-tv') {
        debugPrint('DeepLink: Switching to Live TV tab');
        _switchTab(2);
      }
      // 6. Movies tab: /movies
      else if (fullPath == '/movies') {
        debugPrint('DeepLink: Switching to Movies/Home tab');
        _switchTab(0);
      }
      // 7. Config page (no base URL param — just open the setup portal)
      else if (fullPath == '/config' || fullPath.contains('config')) {
        debugPrint('DeepLink: Explicitly opening OnboardingScreen (Setup Portal)');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => OnboardingScreen()),
          (route) => false,
        );
      }
      // 8. Home
      else if (fullPath == '/' || fullPath.isEmpty) {
        debugPrint('DeepLink: Navigating to home');
        _switchTab(0);
      }
      // 9. Search
      else if (fullPath.startsWith('/search')) {
        final query = params['query'] ?? params['q'];
        if (query != null && query.isNotEmpty) {
          debugPrint('DeepLink: Searching for: $query');
          _navigateToSearch(query);
        }
      } else {
        debugPrint('DeepLink: Unrecognized path: $fullPath');
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Waits up to 3 seconds for the navigator to become available.
  Future<void> _waitForNavigator() async {
    int retryCount = 0;
    while (navigatorKey.currentState == null && retryCount < 15) {
      await Future.delayed(const Duration(milliseconds: 200));
      retryCount++;
    }
  }

  void _refreshApp() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  void _navigateToSearch(String query) {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query)),
    );
  }

  Future<void> _navigateToDetails(int id, String type) async {
    // Wait for navigator to be ready
    await _waitForNavigator();
    
    if (navigatorKey.currentState == null) {
      debugPrint('DeepLink Error: Navigator still not ready for details navigation');
      return;
    }

    _showLoadingOverlay();

    try {
      final api = ApiService.instance;
      final detail = type == 'movie'
          ? await api.getMovieDetail(id)
          : await api.getTvDetail(id);

      _hideLoadingOverlay();

      if (detail != null) {
        debugPrint('DeepLink: Detail fetched, preparing navigation stack');
        
        // Ensure MainNavigation is the root. 
        // If we're already on MainNavigation (first route), just push.
        // If we're not or want to be safe, we can use pushAndRemoveUntil.
        
        final context = navigatorKey.currentContext;
        if (context != null) {
          // Push DetailScreen on top of MainNavigation. 
          // We use pushAndRemoveUntil to ensure the stack is exactly [MainNavigation, DetailScreen]
          // This prevents the "black screen" issue where the stack might be empty or inconsistent.
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
          );
          
          // Now push the Details
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => DetailScreen(item: detail)),
          );
        }
      } else {
        debugPrint('DeepLink Error: Detail returned null for id=$id type=$type');
      }
    } catch (e) {
      _hideLoadingOverlay();
      debugPrint('DeepLink Error fetching detail: $e');
    }
  }

  void _switchTab(int index) {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _onTabChange?.call(index);
  }

  bool _isLoadingShowing = false;

  void _hideLoadingOverlay() {
    if (!_isLoadingShowing) return;
    _isLoadingShowing = false;
    navigatorKey.currentState?.pop();
  }

  void _showSnackBar(String message, {required bool isError}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.red.shade900 : Colors.green.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoadingOverlay({String message = 'Loading...'}) {
    if (_isLoadingShowing) return;
    _isLoadingShowing = true;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: M3LoadingOverlay(message: message),
      ),
    );
  }
}
