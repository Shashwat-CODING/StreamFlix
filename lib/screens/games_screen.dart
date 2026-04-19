import '../services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import '../models/game.dart';
import 'game_view_screen.dart';
import '../widgets/shimmer_placeholder.dart';
import 'search_screen.dart';
import '../widgets/m3_loading.dart';
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
        Navigator.push(
          context,
          MaterialPageRoute(
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const M3Loading(message: 'Loading Playables...'),
                ],
              ),
            )
          : RefreshIndicator.adaptive(
              onRefresh: _load,
              color: cs.primary,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      _buildAppBar(cs),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _buildScrollingCarousel(cs),
                            const NativeAdWidget(size: NativeAdSize.small),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'All Games',
                                style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 20,
                                  color: cs.onSurface,
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
                              ).animate().fadeIn(delay: (index * 20).ms, duration: 350.ms);
                            },
                            childCount: _allGames.length > 6 ? _allGames.length - 6 : 0,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: NativeAdWidget(size: NativeAdSize.medium),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(child: BannerAdWidget()),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAppBar(ColorScheme cs) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
      title: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Image.asset('assets/logo.png', width: 24, height: 24).animate().fadeIn(duration: 400.ms),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'Mini ',
                    style: TextStyle(color: cs.onSurface),
                  ),
                  const TextSpan(
                    text: 'Games',
                    style: TextStyle(color: Color(0xFFE50914)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
            icon: Icon(CupertinoIcons.search, color: cs.onSurface, size: 24),
          ).animate().fadeIn(delay: 200.ms),
        ),
      ],
    );
  }

  Widget _buildScrollingCarousel(ColorScheme cs) {
    if (_featured.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 210,
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
                    color: cs.surfaceContainerHigh,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: game.thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: cs.surfaceContainerHigh),
                        errorWidget: (_, _, _) => const Icon(Icons.videogame_asset),
                      ),
                      // Gradient overlay
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.88),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                      // Left side strip
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4,
                        child: Container(color: const Color(0xFFE50914)),
                      ),
                      // Content
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: Text(
                                'FEATURED PLAYABLE',
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              game.name,
                              style: GoogleFonts.dmSerifDisplay(
                                color: Colors.white,
                                fontSize: 26,
                                height: 1.1,
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
        const SizedBox(height: 12),
        // Page indicators
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_featured.length, (i) {
            final active = i == _carouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFE50914)
                    : cs.onSurface.withValues(alpha: 0.3),
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

  const _GameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 2 / 3, // Maintains the vertical rectangle ratio
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surfaceContainerHigh,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
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
              placeholder: (_, _) => const ShimmerPlaceholder(
                width: double.infinity,
                height: double.infinity,
              ),
              errorWidget: (_, _, _) => Center(
                child: Icon(
                  CupertinoIcons.game_controller_solid,
                  color: cs.onSurfaceVariant,
                  size: 30,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 100,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.1, 1.0]
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, splashColor: Colors.white12),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                game.name,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.2,
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

