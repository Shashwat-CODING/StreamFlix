import 'dart:ui';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/tvshows_screen.dart';
import 'screens/livetv_screen.dart';
import 'screens/search_screen.dart';
import 'services/watch_history.dart';
import 'services/bookmark_service.dart';
import 'services/api_service.dart';
import 'services/streaming_service.dart';

import 'screens/library_screen.dart';
import 'screens/games_screen.dart';
import 'screens/permission_gate_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_service.dart';
import 'services/deeplink_service.dart';
import 'screens/onboarding_screen.dart';
import 'services/permission_service.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'services/window_service.dart';
import 'dart:io';

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
  
  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = "Drishya";
    // Request all permissions immediately at startup — shows native system dialogs
    await PermissionService.requestAll();
  }

  await WindowService.init();
  
  await StreamingService.instance.initDownloads();
  runApp(const DrishyaApp());
}

class DrishyaApp extends StatefulWidget {
  const DrishyaApp({super.key});

  @override
  State<DrishyaApp> createState() => _DrishyaAppState();
}

class _DrishyaAppState extends State<DrishyaApp> {
  bool _needsPermissionGate = false;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    DeepLinkService.instance.init();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final needs = await PermissionService.needsPermissionCheck();
    if (mounted) {
      setState(() {
        _needsPermissionGate = needs;
        _permissionChecked = true;
      });
    }
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (_, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Drishya',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: ThemeMode.system,
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    // While we haven't checked yet — show a brief splash
    if (!_permissionChecked) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2),
        ),
      );
    }

    // Show permission gate if needed (fresh install OR app update with no permission)
    if (_needsPermissionGate) {
      return PermissionGateScreen(
        onComplete: () {
          if (mounted) setState(() => _needsPermissionGate = false);
        },
      );
    }

    // Normal app flow
    if (!ApiService.instance.isConfigured) return const OnboardingScreen();
    return const MainNavigation();
  }
}

// ── Navigation Items ───────────────────────────────────────────────────────────
const List<_NavItem> _navItems = [
  _NavItem(
    icon: CupertinoIcons.house,
    selectedIcon: CupertinoIcons.house_fill,
    label: 'Home',
  ),
  _NavItem(
    icon: CupertinoIcons.tv,
    selectedIcon: CupertinoIcons.tv_fill,
    label: 'TV',
  ),
  _NavItem(
    icon: CupertinoIcons.play_rectangle,
    selectedIcon: CupertinoIcons.play_rectangle_fill,
    label: 'Live',
  ),
  _NavItem(
    icon: CupertinoIcons.gamecontroller,
    selectedIcon: CupertinoIcons.gamecontroller_fill,
    label: 'Games',
  ),
  _NavItem(
    icon: CupertinoIcons.square_grid_2x2,
    selectedIcon: CupertinoIcons.square_grid_2x2_fill,
    label: 'Library',
  ),
];

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _idx = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
    
    // Update DeepLink listener with tab change callback
    DeepLinkService.instance.init(onTabChange: (idx) {
      if (mounted) setState(() => _idx = idx);
    });

    _screens = [
      HomeScreen(
        onSearch: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, _, _) => SearchScreen(),
              transitionsBuilder: (_, anim, _, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 220),
            ),
          );
        },
      ),
      const TvShowsScreen(),
      const LiveTvScreen(),
      const GamesScreen(),
      LibraryScreen(
        onSearch: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, _, _) => SearchScreen(),
              transitionsBuilder: (_, anim, _, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 220),
            ),
          );
        },
      ),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    final update = await ApiService.instance.checkForUpdate();
    if (update != null && mounted) {
      _showUpdateDialog(update);
    }
  }

  void _showUpdateDialog(Map<String, dynamic> update) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            Icon(
              CupertinoIcons.arrow_down_circle_fill,
              color: cs.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Update Available',
              style: GoogleFonts.dmSans(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version (${update['version']}) of Drishya is available. Would you like to update now?',
              style: GoogleFonts.dmSans(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (update['changelog'] != null &&
                update['changelog'].isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'What\'s new:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'DM Sans',
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: update['changelog'],
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.dmSans(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      listBullet: GoogleFonts.dmSans(
                        color: cs.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: TextStyle(color: cs.primary)),
          ),
          FilledButton(
            onPressed: () {
              launchUrl(
                Uri.parse(update['url']),
                mode: LaunchMode.externalApplication,
              );
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Update Now',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;
        final cs = Theme.of(context).colorScheme;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _idx,
                  onDestinationSelected: (i) => setState(() => _idx = i),
                  backgroundColor: cs.surface,
                  indicatorColor: cs.primary.withValues(alpha: 0.15),
                  selectedIconTheme: IconThemeData(color: cs.primary),
                  unselectedIconTheme: IconThemeData(
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                  selectedLabelTextStyle: GoogleFonts.dmSans(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  unselectedLabelTextStyle: GoogleFonts.dmSans(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/ic_launcher.png',
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Drishya',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(CupertinoIcons.house),
                      selectedIcon: Icon(CupertinoIcons.house_fill),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(CupertinoIcons.tv),
                      selectedIcon: Icon(CupertinoIcons.tv_fill),
                      label: Text('TV'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(CupertinoIcons.play_rectangle),
                      selectedIcon: Icon(CupertinoIcons.play_rectangle_fill),
                      label: Text('Live'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(CupertinoIcons.gamecontroller),
                      selectedIcon: Icon(CupertinoIcons.gamecontroller_fill),
                      label: Text('Games'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(CupertinoIcons.square_grid_2x2),
                      selectedIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
                      label: Text('Library'),
                    ),
                  ],
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: IndexedStack(index: _idx, children: _screens),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          extendBody: true,
          body: IndexedStack(index: _idx, children: _screens),
          bottomNavigationBar: _LiquidGlassNavBar(
            selectedIndex: _idx,
            items: _navItems,
            onTap: (i) => setState(() => _idx = i),
            isDark: isDark,
          ),
        );
      },
    );
  }
}

// ── Apple Liquid Glass Floating Navigation Bar ────────────────────────────────

class _LiquidGlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _LiquidGlassNavBar({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final navWidth = (screenWidth * 0.94).clamp(280.0, 500.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: navWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    // Ultra-Liquid Glass: Deeply translucent to let colors "bleed" through
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.05),
                              Colors.white.withValues(alpha: 0.02),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.4),
                              Colors.white.withValues(alpha: 0.1),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                    boxShadow: [
                      // Subtle "floating" outer shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                        blurRadius: 30,
                        spreadRadius: -6,
                        offset: const Offset(0, 10),
                      ),
                      // Subtle inner brand glow to "mix" with background
                      BoxShadow(
                        color: cs.primary.withValues(alpha: isDark ? 0.06 : 0.04),
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: List.generate(items.length, (i) {
                      return Expanded(
                        child: _GlassNavItem(
                          item: items[i],
                          selected: i == selectedIndex,
                          onTap: () => onTap(i),
                          isDark: isDark,
                          accentColor: cs.primary,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color accentColor;

  const _GlassNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: isDark ? 0.28 : 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
                    blurRadius: 10,
                    spreadRadius: -2,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                key: ValueKey(selected),
                size: 22,
                color: selected
                    ? accentColor
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.black.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.dmSans(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? accentColor
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.black.withValues(alpha: 0.7)),
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nav Item Data ─────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
