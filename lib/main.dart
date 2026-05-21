import 'dart:ui';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart' hide MediaItem;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/tvshows_screen.dart';
import 'screens/livetv_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/games_screen.dart';
import 'screens/music_screen.dart';
import 'screens/arts_screen.dart';
import 'screens/music_player_screen.dart';
import 'services/music_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/permission_gate_screen.dart';
import 'screens/anime_screen.dart';
import 'screens/detail_screen.dart';
import 'models/media_item.dart';

import 'services/watch_history.dart';
import 'services/music_history.dart';
import 'services/bookmark_service.dart';
import 'services/api_service.dart';
import 'services/streaming_service.dart';
import 'services/ad_service.dart';
import 'services/deeplink_service.dart';
import 'services/window_service.dart';
import 'models/song_model.dart';
import 'widgets/mini_player_wrapper.dart';
import 'services/settings_service.dart';
import 'services/collection_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'screens/settings_screen.dart';
import 'screens/auth_screen.dart';
import 'widgets/ios_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    MobileAds.instance.initialize();
    AdService.loadRewardedAd();
  }
  fvp.registerWith(options: {'video.decoders': ['D3D11', 'NVDEC', 'FFmpeg']});
  await WatchHistory.load();
  await MusicHistory.load();
  await BookmarkService.init();
  await ApiService.instance.init();
  await WindowService.init();
  await StreamingService.instance.initDownloads();
  
  // Initialize Audio Service for background playback
  await MusicService.instance.init();
  
  // Initialize Settings
  await SettingsService.instance.init();

  // Initialize Collection Service
  await CollectionService.instance.init();

  // Initialize Auth
  await AuthService.instance.init();
  
  runApp(const LuxaApp());
}

class LuxaApp extends StatefulWidget {
  const LuxaApp({super.key});

  @override
  State<LuxaApp> createState() => _LuxaAppState();
}

class _LuxaAppState extends State<LuxaApp> with WidgetsBindingObserver {
  bool _needsPermissionGate = false;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeepLinkService.instance.init();
    _checkPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed. Restoring cloud data...');
      SyncService.instance.restoreAll();
    }
  }

  Future<void> _checkPermissions() async {
    // Basic check for now, can be expanded to check specific permissions via PermissionService
    if (mounted) {
      setState(() {
        _needsPermissionGate = false; 
        _permissionChecked = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final settings = SettingsService.instance;
        return CupertinoApp(
          navigatorKey: navigatorKey,
          title: 'Luxa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.iosTheme(
            settings.themeMode == 1 
                ? Brightness.dark 
                : settings.themeMode == 2 
                    ? Brightness.light 
                    : MediaQuery.platformBrightnessOf(context),
            customFont: settings.customFont
          ),
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (!_permissionChecked) {
      return const CupertinoPageScaffold(
        backgroundColor: Color(0xFF0A0A0A),
        child: Center(
          child: CupertinoActivityIndicator(radius: 15, color: Color(0xFFE50914)),
        ),
      );
    }

    if (_needsPermissionGate) {
      return PermissionGateScreen(
        onComplete: () {
          if (mounted) setState(() => _needsPermissionGate = false);
        },
      );
    }

    return const MainNavigation();
  }
}

// ── Navigation Items ───────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int screenIndex;
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screenIndex,
  });
}

const List<_NavItem> _mainNavItems = [
  _NavItem(icon: CupertinoIcons.house, selectedIcon: CupertinoIcons.house_fill, label: 'Home', screenIndex: 0),
  _NavItem(icon: CupertinoIcons.tv, selectedIcon: CupertinoIcons.tv_fill, label: 'TV', screenIndex: 1),
  _NavItem(icon: CupertinoIcons.music_note_2, selectedIcon: CupertinoIcons.music_albums_fill, label: 'Music', screenIndex: 2),
  _NavItem(icon: CupertinoIcons.sparkles, selectedIcon: CupertinoIcons.sparkles, label: 'Anime', screenIndex: 3),
  _NavItem(icon: CupertinoIcons.square_stack_3d_up, selectedIcon: CupertinoIcons.square_stack_3d_up_fill, label: 'Library', screenIndex: 4),
  _NavItem(icon: CupertinoIcons.play_rectangle, selectedIcon: CupertinoIcons.play_rectangle_fill, label: 'Live', screenIndex: 5),
  _NavItem(icon: CupertinoIcons.gamecontroller, selectedIcon: CupertinoIcons.gamecontroller_fill, label: 'Games', screenIndex: 6),
  _NavItem(icon: CupertinoIcons.photo, selectedIcon: CupertinoIcons.photo_fill, label: 'Arts', screenIndex: 7),
  _NavItem(icon: CupertinoIcons.settings, selectedIcon: CupertinoIcons.settings, label: 'Settings', screenIndex: 8),
];

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _idx = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowAuth());
    
    DeepLinkService.instance.init(onTabChange: (idx) {
      if (mounted) setState(() => _idx = idx);
    });

    _screens = [
      HomeScreen(
        onSearch: () => Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(builder: (_) => const SearchScreen()),
        ),
      ),
      const TvShowsScreen(),
      const MusicScreen(),
      AnimeScreen(
        onSearch: () => Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(builder: (_) => const AnimeSearchScreen()),
        ),
      ),
      LibraryScreen(
        onSearch: () => Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(builder: (_) => const SearchScreen()),
        ),
      ),
      const LiveTvScreen(),
      const GamesScreen(),
      const ArtsScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: CupertinoColors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: CupertinoColors.transparent,
      ),
    );

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Row(
            children: [
              _buildSidebar(theme),
              Expanded(child: _buildNavigator()),
            ],
          ),
          ListenableBuilder(
            listenable: MusicService.instance,
            builder: (context, _) {
              final song = MusicService.instance.currentSong;
              if (song == null) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MiniPlayer(song: song),
              );
            },
          ),
        ],
      ),
    );
  }



  Widget _buildNavigator() {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) {
            if (settings.name == '/details') {
              return DetailScreen(item: settings.arguments as MediaItem);
            }
            if (settings.name == '/search') {
              return const SearchScreen();
            }
            return IndexedStack(index: _idx, children: _screens);
          },
        );
      },
    );
  }

  Widget _buildSidebar(CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 40, // More compact width
      child: Column(
        children: [
          const SizedBox(height: 60),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 10), // Reduced vertical padding
              child: Column(
                children: List.generate(_mainNavItems.length, (i) {
                  final item = _mainNavItems[i];
                  final active = _idx == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10), // Reduced distancing
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _idx = i;
                        _navigatorKey.currentState?.popUntil((r) => r.isFirst);
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Text(
                          item.label.toUpperCase(),
                          style: theme.textTheme.textStyle.copyWith(
                            color: active ? theme.primaryColor : CupertinoColors.systemGrey,
                            fontWeight: active ? FontWeight.bold : FontWeight.w600,
                            letterSpacing: 2.0, // Reduced letter spacing
                            fontSize: 11, // Smaller font size
                          ),
                        ),
                      ),
                    ).animate(target: active ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05)),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Future<void> _checkUpdate() async {
    final update = await ApiService.instance.checkForUpdate();
    if (update != null && mounted) {
      _showUpdateDialog(update);
    }
  }

  Future<void> _maybeShowAuth() async {
    if (AuthService.instance.isAuthenticated) return;
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_auth') ?? false;
    if (hasSeen) return;
    await prefs.setBool('has_seen_auth', true);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => const AuthScreen(showSkip: true)),
    );
  }

  void _showUpdateDialog(Map<String, dynamic> update) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Update Available'),
        content: Text('A new version (${update['version']}) is available.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              launchUrl(Uri.parse(update['url']), mode: LaunchMode.externalApplication);
              Navigator.pop(context);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}






