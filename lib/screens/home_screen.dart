import 'dart:ui';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_placeholder.dart';
import 'detail_screen.dart';
import '../services/watch_history.dart';
import 'search_screen.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/ios_widgets.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSearch;
  const HomeScreen({super.key, this.onSearch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService.instance;
  List<MediaItem> _trending = [];
  List<MediaItem> _popularMovies = [];
  List<MediaItem> _nowPlayingMovies = [];
  List<MediaItem> _animeMovies = [];
  bool _loading = true;

  int _heroIndex = 0;
  Timer? _heroTimer;
  final PageController _heroController = PageController(viewportFraction: 0.9);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _api.getTrendingMovies(),
      _api.getPopularMovies(),
      _api.getNowPlayingMovies(),
      _api.getAnimeMovies(),
    ]);
    if (mounted) {
      setState(() {
        _trending = results[0];
        _popularMovies = results[1];
        _nowPlayingMovies = results[2];
        _animeMovies = results[3];
        _loading = false;
      });
      _startHeroTimer();
    }
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _trending.isEmpty || !_heroController.hasClients) return;
      final next = (_heroIndex + 1) % _trending.take(5).length;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _openDetail(MediaItem item) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => DetailScreen(item: item)),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CupertinoPageScaffold(
      child: _loading
          ? const Center(child: IOSLoading(message: 'Curating the best content for you...'))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverNavigationBar(
                  transitionBetweenRoutes: false,
                  largeTitle: Text('Home', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  backgroundColor: isDark ? const Color(0xCC000000) : const Color(0xCCF2F2F7),
                  border: null,
                  trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          if (widget.onSearch != null) {
                            widget.onSearch!();
                          } else {
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(builder: (_) => const SearchScreen()),
                            );
                          }
                        },
                        child: const Icon(CupertinoIcons.search, size: 24),
                      ),
                ),

                SliverToBoxAdapter(
                  child: _HeroCarousel(
                    items: _trending.take(5).toList(),
                    heroIndex: _heroIndex,
                    controller: _heroController,
                    onPageChanged: (i) => setState(() => _heroIndex = i),
                    onTap: _openDetail,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildContinueWatching(),
                      const SizedBox(height: 12),
                      _ContentSection(
                        title: 'Trending Now',
                        icon: CupertinoIcons.flame_fill,
                        iconColor: const Color(0xFFFF6240),
                        items: _trending,
                        onTap: _openDetail,
                      ),
                      const SizedBox(height: 12),
                      _ContentSection(
                        title: 'Now Playing',
                        icon: CupertinoIcons.play_rectangle_fill,
                        iconColor: theme.primaryColor,
                        items: _nowPlayingMovies,
                        onTap: _openDetail,
                      ),
                      const SizedBox(height: 12),
                      _ContentSection(
                        title: 'Popular Movies',
                        icon: CupertinoIcons.film_fill,
                        iconColor: const Color(0xFF8B6FCA),
                        items: _popularMovies,
                        onTap: _openDetail,
                      ),
                      const SizedBox(height: 12),
                      _ContentSection(
                        title: 'Anime Hits',
                        icon: CupertinoIcons.sparkles,
                        iconColor: const Color(0xFFFF8C42),
                        items: _animeMovies,
                        onTap: _openDetail,
                      ),
                      const NativeAdWidget(size: NativeAdSize.medium),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildContinueWatching() {
    final history = WatchHistory.history.where((e) => e.mediaType != 'music').toList();
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Continue Watching',
          icon: CupertinoIcons.clock_fill,
          iconColor: Color(0xFF3EC6C6),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _ContinueCard(
              item: history[i],
              onTap: () => _openDetail(history[i]),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    ).animate().fadeIn(delay: 50.ms);
  }

}

class _HeroCarousel extends StatelessWidget {
  final List<MediaItem> items;
  final int heroIndex;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<MediaItem> onTap;

  const _HeroCarousel({
    required this.items,
    required this.heroIndex,
    required this.controller,
    required this.onPageChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;
    final cardH = (screenH * 0.5).clamp(300.0, 500.0);

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: cardH,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: items.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: _HeroCard(
                item: items[i],
                onTap: () => onTap(items[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            final active = i == heroIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 6),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? theme.primaryColor : (isDark ? CupertinoColors.white.withValues(alpha: 0.24) : CupertinoColors.black.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _HeroCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.fullBackdropUrl.isNotEmpty ? item.fullBackdropUrl : item.fullPosterUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: CupertinoColors.black.withValues(alpha: 0.12)),
              errorWidget: (_, _, _) => Container(color: CupertinoColors.black.withValues(alpha: 0.12)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.4, 1.0],
                  colors: [const Color(0x00000000), CupertinoColors.black.withValues(alpha: 0.87)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.outfit(
                      color: CupertinoColors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.mediaType.toUpperCase(),
                          style: GoogleFonts.outfit(color: CupertinoColors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(CupertinoIcons.star_fill, size: 14, color: Color(0xFFFFCB45)),
                      const SizedBox(width: 4),
                      Text(item.ratingStr, style: GoogleFonts.outfit(color: CupertinoColors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _ContinueCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (item.position ?? 0) / (item.duration ?? 1).clamp(1.0, double.infinity);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.fullBackdropUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: CupertinoColors.black.withValues(alpha: 0.12)),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0x00000000), CupertinoColors.black.withValues(alpha: 0.54)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: GoogleFonts.outfit(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1),
                    const SizedBox(height: 6),
                    Container(
                      height: 3,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: CupertinoColors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Center(child: Icon(CupertinoIcons.play_circle_fill, color: CupertinoColors.white.withValues(alpha: 0.70), size: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader({required this.title, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: Text('See All', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;

  const _ContentSection({required this.title, required this.icon, required this.iconColor, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _SectionHeader(title: title, icon: icon, iconColor: iconColor),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _ContentCard(item: items[i], onTap: () => onTap(items[i])),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _ContentCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 120,
          child: CachedNetworkImage(
            imageUrl: item.fullPosterUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: CupertinoColors.black.withValues(alpha: 0.12)),
          ),
        ),
      ),
    );
  }
}
