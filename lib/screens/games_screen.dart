import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_service.dart';
import '../models/game.dart';
import 'game_view_screen.dart';
import '../widgets/shimmer_placeholder.dart';
import 'search_screen.dart';
import '../widgets/ios_widgets.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/native_ad_widget.dart';
import '../services/ad_service.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final _api = ApiService.instance;

  List<Game> _allGames = [];
  List<Game> _featured = [];
  bool _loading = true;

  // Auto-scroll carousel
  int _carouselIndex = 0;
  Timer? _carouselTimer;
  final PageController _carouselCtrl = PageController(viewportFraction: 0.88);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _featured.isEmpty) return;
      if (!_carouselCtrl.hasClients) return;
      final next = (_carouselIndex + 1) % _featured.length;
      _carouselCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final games = await _api.fetchGames();
      if (mounted) {
        setState(() {
          _allGames = games;
          _featured = _allGames.take(6).toList();
          _loading = false;
        });
        _startCarousel();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselCtrl.dispose();
    super.dispose();
  }

  void _openDetail(Game game) {
    AdService.showRewardedAd(
      context: context,
      message: 'Watch the full ad to play ${game.name}.',
      onComplete: () {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (context) => GameViewScreen(
              url: game.url,
              title: game.name,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return CupertinoPageScaffold(
        child: const Center(child: IOSLoading(message: 'Loading Playables...')),
      );
    }

    return CupertinoPageScaffold(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: Text('Mini Games', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            backgroundColor: theme.barBackgroundColor.withValues(alpha: 0.8),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(builder: (_) => const SearchScreen())),
              child: const Icon(CupertinoIcons.search),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildScrollingCarousel(theme, isDark),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: NativeAdWidget(size: NativeAdSize.small),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'All Games',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 155,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final game = _allGames.skip(6).toList()[index];
                  return _GameCard(
                    game: game,
                    onTap: () => _openDetail(game),
                    isDark: isDark,
                  ).animate().fadeIn(delay: (index * 20).ms, duration: 350.ms);
                },
                childCount: _allGames.length > 6 ? _allGames.length - 6 : 0,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: NativeAdWidget(size: NativeAdSize.medium),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(child: BannerAdWidget()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildScrollingCarousel(CupertinoThemeData theme, bool isDark) {
    if (_featured.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _carouselCtrl,
            onPageChanged: (i) => setState(() => _carouselIndex = i),
            itemCount: _featured.length,
            itemBuilder: (_, i) {
              final game = _featured[i];
              return GestureDetector(
                onTap: () => _openDetail(game),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: game.thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                        errorWidget: (_, _, _) => const Icon(CupertinoIcons.gamecontroller, size: 40),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              CupertinoColors.transparent,
                              CupertinoColors.black.withValues(alpha: 0.9),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: CupertinoColors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: CupertinoColors.white.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: Text(
                                'FEATURED',
                                style: GoogleFonts.outfit(
                                  color: CupertinoColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              game.name,
                              style: GoogleFonts.outfit(
                                color: CupertinoColors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_featured.length, (i) {
            final active = i == _carouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? theme.primaryColor : (isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey4),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  final bool isDark;

  const _GameCard({required this.game, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
          border: Border.all(color: (isDark ? CupertinoColors.white : CupertinoColors.black).withValues(alpha: 0.08), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: game.thumbnail,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ShimmerPlaceholder(width: double.infinity, height: double.infinity),
              errorWidget: (_, _, _) => Center(child: Icon(CupertinoIcons.gamecontroller_fill, color: CupertinoColors.systemGrey, size: 30)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [CupertinoColors.transparent, CupertinoColors.black.withValues(alpha: 0.9)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                game.name,
                style: GoogleFonts.outfit(
                  color: CupertinoColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




