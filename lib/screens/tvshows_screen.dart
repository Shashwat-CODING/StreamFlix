import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/media_item.dart';
import '../services/api_service.dart';
import 'detail_screen.dart';
import '../widgets/shimmer_placeholder.dart';
import 'search_screen.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/ios_widgets.dart';

class TvShowsScreen extends StatefulWidget {
  const TvShowsScreen({super.key});

  @override
  State<TvShowsScreen> createState() => _TvShowsScreenState();
}

class _TvShowsScreenState extends State<TvShowsScreen> {
  final _api = ApiService.instance;
  List<MediaItem> _trending = [];
  List<MediaItem> _popular = [];
  List<MediaItem> _topRated = [];
  List<MediaItem> _airingToday = [];
  bool _loading = true;

  int _carouselIndex = 0;
  Timer? _carouselTimer;
  final PageController _carouselCtrl = PageController(viewportFraction: 0.9);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _trending.isEmpty) return;
      if (!_carouselCtrl.hasClients) return;
      final next = (_carouselIndex + 1) % _trending.take(6).length;
      _carouselCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _api.getTrendingTv(),
      _api.getPopularTvShows(),
      _api.getTopRatedTvShows(),
      _api.getAiringTodayTv(),
    ]);
    if (mounted) {
      setState(() {
        _trending = results[0];
        _popular = results[1];
        _topRated = results[2];
        _airingToday = results[3];
        _loading = false;
      });
      _startCarousel();
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselCtrl.dispose();
    super.dispose();
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
          ? const Center(child: IOSLoading(message: 'Gathering your favorite shows...'))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverNavigationBar(
                  transitionBetweenRoutes: false,
                  largeTitle: Text('TV Shows', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  backgroundColor: isDark ? const Color(0xCC000000) : const Color(0xCCF2F2F7),
                  border: null,
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      CupertinoPageRoute(builder: (_) => const SearchScreen()),
                    ),
                    child: const Icon(CupertinoIcons.search, size: 22),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildScrollingCarousel(theme),
                      const SizedBox(height: 24),
                      _buildSection('Trending', CupertinoIcons.graph_circle, const Color(0xFFFF6240), _trending),
                      _buildSection('Airing Today', CupertinoIcons.sparkles, theme.primaryColor, _airingToday),
                      _buildSection('All-Time Best', CupertinoIcons.rosette, const Color(0xFFFFCB45), _topRated),
                      _buildSection('Popular Right Now', CupertinoIcons.flame_fill, const Color(0xFF9C6FDE), _popular),
                      const NativeAdWidget(size: NativeAdSize.medium),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildScrollingCarousel(CupertinoThemeData theme) {
    if (_trending.isEmpty) return const SizedBox.shrink();
    final items = _trending.take(6).toList();
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _carouselCtrl,
            onPageChanged: (i) => setState(() => _carouselIndex = i),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return GestureDetector(
                onTap: () => _openDetail(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: item.fullBackdropUrl.isNotEmpty ? item.fullBackdropUrl : item.fullPosterUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: CupertinoColors.black.withValues(alpha: 0.12)),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [const Color(0x00000000), CupertinoColors.black.withValues(alpha: 0.87)],
                              stops: [0.4, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.outfit(color: CupertinoColors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            final active = i == _carouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
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

  Widget _buildSection(String title, IconData icon, Color iconColor, List<MediaItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? CupertinoColors.white : CupertinoColors.black),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {},
                child: const Text('See All', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _TvPosterCard(item: items[i], onTap: () => _openDetail(items[i])),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _TvPosterCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _TvPosterCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 140,
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
