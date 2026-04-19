import 'dart:async';
import 'package:flutter/material.dart';
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
import '../widgets/m3_loading.dart';
import '../widgets/native_ad_widget.dart';

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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    ).then((_) => setState(() {}));
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
                children: [const M3Loading(message: 'Gathering your favorite shows...')],
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
                            const SizedBox(height: 24),
                            _buildSection(
                              'Trending',
                              CupertinoIcons.graph_circle,
                              const Color(0xFFFF6240),
                              _trending,
                              0,
                            ),
                            _buildSection(
                              'Airing Today',
                              CupertinoIcons.sparkles,
                              const Color(0xFFE50914),
                              _airingToday,
                              60,
                            ),
                            const NativeAdWidget(size: NativeAdSize.medium),
                            BannerAdWidget(),
                            _buildSection(
                              'All-Time Best',
                              CupertinoIcons.rosette,
                              const Color(0xFFFFCB45),
                              _topRated,
                              120,
                            ),
                            _buildSection(
                              'Popular Right Now',
                              CupertinoIcons.flame_fill,
                              const Color(0xFF9C6FDE),
                              _popular,
                              180,
                            ),
                            BannerAdWidget(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
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
                    text: 'TV ',
                    style: TextStyle(color: cs.onSurface),
                  ),
                  TextSpan(
                    text: 'Shows',
                    style: TextStyle(color: const Color(0xFFE50914)),
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
    if (_trending.isEmpty) return const SizedBox.shrink();
    final items = _trending.take(6).toList();

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _carouselCtrl,
            onPageChanged: (i) => setState(() => _carouselIndex = i),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return GestureDetector(
                onTap: () => _openDetail(item),
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
                        imageUrl: item.fullBackdropUrl.isNotEmpty
                            ? item.fullBackdropUrl
                            : item.fullPosterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: cs.surfaceContainerHigh),
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
                                'TRENDING #${i + 1}',
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
                              item.title,
                              style: GoogleFonts.dmSerifDisplay(
                                color: Colors.white,
                                fontSize: 26,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (item.voteAverage > 0) ...[
                                  const Icon(
                                    CupertinoIcons.star_fill,
                                    size: 13,
                                    color: Color(0xFFFFCB45),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.ratingStr,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Text(
                                  item.year,
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
          children: List.generate(items.length, (i) {
            final active = i == _carouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFE50914)
                    : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color iconColor,
    List<MediaItem> items,
    int delay,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 20,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See all',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length.clamp(0, 12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 155,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) => _TvPosterCard(
                item: items[i],
                onTap: () => _openDetail(items[i]),
              ).animate().fadeIn(delay: (i * 28).ms, duration: 280.ms),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _TvPosterCard(
                item: items[i],
                onTap: () => _openDetail(items[i]),
              ).animate().fadeIn(delay: (i * 40).ms, duration: 350.ms),
            ),
          ),
        const SizedBox(height: 32),
      ],
    ).animate().fadeIn(delay: delay.ms);
  }
}

class _TvPosterCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _TvPosterCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 2 / 3,
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
              imageUrl: item.fullPosterUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ShimmerPlaceholder(
                width: double.infinity,
                height: double.infinity,
              ),
              errorWidget: (_, _, _) => Center(
                child: Icon(
                  CupertinoIcons.tv_fill,
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
            if (item.voteAverage > 0)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.star_fill,
                        size: 10,
                        color: Color(0xFFFFCB45),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        item.ratingStr,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                item.title,
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
