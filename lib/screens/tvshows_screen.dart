import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import 'detail_screen.dart';
import '../services/watch_history.dart';
import '../widgets/shimmer_placeholder.dart';
import 'search_screen.dart';
import '../widgets/m3_loading.dart';

class TvShowsScreen extends StatefulWidget {
  const TvShowsScreen({super.key});

  @override
  State<TvShowsScreen> createState() => _TvShowsScreenState();
}

class _TvShowsScreenState extends State<TvShowsScreen> {
  final _service = TmdbService();
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
      _service.getTrendingTv(),
      _service.getPopularTvShows(),
      _service.getTopRatedTvShows(),
      _service.getAiringTodayTv(),
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
                children: [const M3Loading(message: 'Loading shows...')],
              ),
            )
          : RefreshIndicator.adaptive(
              onRefresh: _load,
              color: cs.primary,
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
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar(ColorScheme cs) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      stretch: true,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Row(
          children: [
            Image.asset('assets/ic_launcher.png', width: 28, height: 28),
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'TV ',
                    style: TextStyle(color: cs.onSurface),
                  ),
                  TextSpan(
                    text: 'Shows',
                    style: TextStyle(color: cs.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          ),
          icon: Icon(CupertinoIcons.search, color: cs.onSurface, size: 22),
        ),
        const SizedBox(width: 6),
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
                        placeholder: (_, __) =>
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
                              Colors.black.withOpacity(0.88),
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
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'TRENDING #${i + 1}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
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
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Text(
                                  item.year,
                                  style: GoogleFonts.inter(
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
                    : Colors.white.withOpacity(0.3),
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
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
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
                  style: GoogleFonts.inter(
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
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _TvPosterCard(
              item: items[i],
              onTap: () => _openDetail(items[i]),
            ).animate().fadeIn(delay: (i * 40).ms, duration: 350.ms),
          ),
        ),
        const SizedBox(height: 28),
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
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
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
              placeholder: (_, __) => const ShimmerPlaceholder(
                width: double.infinity,
                height: double.infinity,
              ),
              errorWidget: (_, __, ___) => Center(
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
              height: 80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
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
                    color: Colors.black.withOpacity(0.65),
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
                        style: GoogleFonts.inter(
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
              bottom: 10,
              left: 10,
              right: 10,
              child: Text(
                item.title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
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
