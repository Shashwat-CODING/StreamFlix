import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/livetv_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/arts_screen.dart';
import 'screens/permission_gate_screen.dart';
import 'screens/anime_screen.dart';
import 'screens/detail_screen.dart';
import 'models/media_item.dart';

import 'services/watch_history.dart';
import 'services/bookmark_service.dart';
import 'services/api_service.dart';
import 'services/streaming_service.dart';
import 'services/ad_service.dart';
import 'services/deeplink_service.dart';
import 'services/window_service.dart';
import 'services/settings_service.dart';
import 'services/collection_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'screens/settings_screen.dart';
import 'screens/auth_screen.dart';
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
  await BookmarkService.init();
  await ApiService.instance.init();
  await WindowService.init();
  await StreamingService.instance.initDownloads();
  
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
  _NavItem(icon: FluentIcons.home_24_regular, selectedIcon: FluentIcons.home_24_filled, label: 'Home', screenIndex: 0),
  _NavItem(icon: FluentIcons.sparkle_24_regular, selectedIcon: FluentIcons.sparkle_24_filled, label: 'Anime', screenIndex: 1),
  _NavItem(icon: FluentIcons.library_24_regular, selectedIcon: FluentIcons.library_24_filled, label: 'Library', screenIndex: 2),
  _NavItem(icon: FluentIcons.live_24_regular, selectedIcon: FluentIcons.live_24_filled, label: 'Live', screenIndex: 3),
  _NavItem(icon: FluentIcons.image_24_regular, selectedIcon: FluentIcons.image_24_filled, label: 'Arts', screenIndex: 4),
  _NavItem(icon: FluentIcons.settings_24_regular, selectedIcon: FluentIcons.settings_24_filled, label: 'Settings', screenIndex: 5),
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
      const ArtsScreen(),
      const SettingsScreen(),
    ];
  }

  Widget _buildSidebar(CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF999999);

    return Container(
      width: 250,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo/Brand
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 24, top: 8),
            child: Text(
              'LUXA',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Nav Items
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mainNavItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = _mainNavItems[i];
                final active = _idx == i;

                return GestureDetector(
                  onTap: () => setState(() {
                    _idx = i;
                    _navigatorKey.currentState?.popUntil((r) => r.isFirst);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: active
                        ? BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8.0),
                          )
                        : const BoxDecoration(
                            color: CupertinoColors.transparent,
                          ),
                    child: Row(
                      children: [
                        Icon(
                          active ? item.selectedIcon : item.icon,
                          color: active ? theme.primaryColor : inactiveColor,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              color: active ? theme.primaryColor : (isDark ? CupertinoColors.white : CupertinoColors.black),
                              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 950;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: CupertinoColors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: CupertinoColors.transparent,
      ),
    );

    if (isWide) {
      return CupertinoPageScaffold(
        backgroundColor: isDark ? CupertinoColors.black : theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            _buildSidebar(theme),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                decoration: AppTheme.brutalistDecoration(
                  context: context,
                  color: isDark ? CupertinoColors.black : theme.scaffoldBackgroundColor,
                  borderRadius: 12.0,
                  hasShadow: false,
                  hasBorder: false,
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildNavigator(),
              ),
            ),
          ],
        ),
      );
    }

    return CupertinoPageScaffold(
      child: Column(
        children: [
          Expanded(child: _buildNavigator()),
          _buildBottomBar(theme),
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

  Widget _buildBottomBar(CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 50 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xCC0A0A0A) : const Color(0xCCFFFFFF),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0x15FFFFFF) : const Color(0x15000000),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_mainNavItems.length, (i) {
              final item = _mainNavItems[i];
              final active = _idx == i;
              final activeColor = theme.primaryColor;
              final inactiveColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF999999);
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _idx = i;
                    _navigatorKey.currentState?.popUntil((r) => r.isFirst);
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6),
                      Icon(
                        active ? item.selectedIcon : item.icon,
                        color: active ? activeColor : inactiveColor,
                        size: 20,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          color: active ? activeColor : inactiveColor,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
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






