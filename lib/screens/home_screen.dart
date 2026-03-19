import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/m3_loading.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../widgets/shimmer_placeholder.dart';
import 'detail_screen.dart';
import '../services/watch_history.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSearch;
  const HomeScreen({super.key, this.onSearch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = TmdbService();
  List<MediaItem> _trending = [];
  List<MediaItem> _popularMovies = [];
  List<MediaItem> _nowPlayingMovies = [];
  List<MediaItem> _animeMovies = [];
  bool _loading = true;

  int _heroIndex = 0;
  Timer? _heroTimer;
  final PageController _heroController = PageController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
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
      _service.getTrendingMovies(),
      _service.getPopularMovies(),
      _service.getNowPlayingMovies(),
      _service.getAnimeMovies(),
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
      if (!mounted || _trending.isEmpty) return;
      if (!_heroController.hasClients) return;
      final next = (_heroIndex + 1) % _trending.take(5).length;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
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
      extendBodyBehindAppBar: true,
      backgroundColor: cs.surface,
      body: _loading
          ? const Center(child: M3Loading(message: 'Loading content...'))
          : RefreshIndicator.adaptive(
              onRefresh: _load,
              color: cs.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHero()),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildContinueWatching(),
                        _buildSection(
                          title: 'Trending Now',
                          icon: CupertinoIcons.flame_fill,
                          iconColor: const Color(0xFFFF6240),
                          items: _trending,
                          delay: 0,
                        ),
                        _buildSection(
                          title: 'Now Playing',
                          icon: CupertinoIcons.play_rectangle_fill,
                          iconColor: const Color(0xFFE50914),
                          items: _nowPlayingMovies,
                          delay: 60,
                        ),
                        _buildSection(
                          title: 'Popular Movies',
                          icon: CupertinoIcons.film_fill,
                          iconColor: const Color(0xFF9C6FDE),
                          items: _popularMovies,
                          delay: 120,
                        ),

                        _buildSection(
                          title: 'Anime Hits',
                          icon: CupertinoIcons.sparkles,
                          iconColor: const Color(0xFFFF8C42),
                          items: _animeMovies,
                          delay: 240,
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

  // ── HERO ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    final cs = Theme.of(context).colorScheme;
    final heroItems = _trending.take(5).toList();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 720;
    final heroHeight = isDesktop
        ? (screenHeight * 0.65).clamp(360.0, 520.0)
        : screenHeight * 0.68;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        children: [
          // Background PageView
          PageView.builder(
            controller: _heroController,
            onPageChanged: (i) => setState(() => _heroIndex = i),
            itemCount: heroItems.length,
            itemBuilder: (_, i) {
              final item = heroItems[i];
              return CachedNetworkImage(
                key: ValueKey(item.id),
                imageUrl: item.fullBackdropUrl.isNotEmpty
                    ? item.fullBackdropUrl
                    : item.fullPosterUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) =>
                    Container(color: cs.surfaceContainerHigh),
                errorWidget: (_, __, ___) =>
                    Container(color: cs.surfaceContainerHigh),
              );
            },
          ),

          // Multi-stop cinematic gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3, 0.65, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                    cs.surface.withOpacity(0.6),
                    cs.surface,
                  ],
                ),
              ),
            ),
          ),

          // Subtle side vignette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),

          // App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Logo — text only, no leading icon
                    Row(
                      children: [
                        Image.asset(
                          'assets/ic_launcher.png',
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(width: 10),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                            children: const [
                              TextSpan(
                                text: 'Stream',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: 'Flix',
                                style: TextStyle(color: Color(0xFFE50914)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms),
                    const Spacer(),
                    _glassAction(
                      icon: CupertinoIcons.search,
                      onTap: () {
                        if (widget.onSearch != null) {
                          widget.onSearch!();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SearchScreen(),
                            ),
                          );
                        }
                      },
                    ).animate().fadeIn(delay: 150.ms),
                  ],
                ),
              ),
            ),
          ),

          // Hero content
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildHeroContent(heroItems),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassAction({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Widget _buildHeroContent(List<MediaItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final item = items[_heroIndex];
    final cs = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey(item.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Metadata row
          Row(
            children: [
              _heroBadge(
                item.mediaType == 'tv' ? 'SERIES' : 'MOVIE',
                const Color(0xFFE50914).withOpacity(0.85),
              ),
              if (item.voteAverage > 0) ...[
                const SizedBox(width: 10),
                const Icon(
                  CupertinoIcons.star_fill,
                  size: 14,
                  color: Color(0xFFFFCB45),
                ),
                const SizedBox(width: 4),
                Text(
                  item.ratingStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Text(
                item.year,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            item.title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.0,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              _heroPlayButton(
                label: item.isUnreleased ? 'SOON' : 'Play Now',
                icon: item.isUnreleased
                    ? CupertinoIcons.clock_fill
                    : CupertinoIcons.play_fill,
                onTap: () => _openDetail(item),
                primary: true,
                cs: cs,
              ),
              const SizedBox(width: 12),
              _heroPlayButton(
                label: 'Details',
                icon: CupertinoIcons.info,
                onTap: () => _openDetail(item),
                primary: false,
                cs: cs,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Page indicators
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(items.length, (i) {
              final active = i == _heroIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                width: active ? 20 : 6,
                height: 4,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFE50914)
                      : Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _heroPlayButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool primary,
    required ColorScheme cs,
  }) {
    if (primary) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.9), size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── CONTINUE WATCHING ─────────────────────────────────────────────────────

  Widget _buildContinueWatching() {
    final history = WatchHistory.history;
    if (history.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Continue Watching',
          CupertinoIcons.clock_fill,
          const Color(0xFF3EC6C6),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 134,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final item = history[i];
              return Container(
                width: 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: cs.surfaceContainerHigh,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: item.fullBackdropUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.fullBackdropUrl,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.75),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(onTap: () => _openDetail(item)),
                      ),
                    ),
                    // Play button overlay
                    Positioned(
                      top: 0,
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: IgnorePointer(
                          child: Icon(
                            CupertinoIcons.play_fill,
                            color: Colors.white.withOpacity(0.9),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: 0.55,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFE50914),
                              ),
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    ).animate().fadeIn(delay: 50.ms);
  }

  // ── HORIZONTAL SECTIONS ───────────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<MediaItem> items,
    required int delay,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 700;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(title, icon, iconColor),
            const SizedBox(height: 14),
            if (isDesktop)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length.clamp(0, 12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    childAspectRatio: 2 / 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemBuilder: (_, i) => _PosterCard(
                    item: items[i],
                    onTap: () => _openDetail(items[i]),
                  ).animate().fadeIn(delay: (i * 30).ms, duration: 300.ms),
                ),
              )
            else
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _PosterCard(
                    item: items[i],
                    onTap: () => _openDetail(items[i]),
                  ).animate().fadeIn(delay: (i * 40).ms, duration: 350.ms),
                ),
              ),
            const SizedBox(height: 28),
          ],
        ).animate().fadeIn(delay: delay.ms);
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color iconColor) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
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
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }
}

// ── POSTER CARD ───────────────────────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _PosterCard({required this.item, required this.onTap});

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
            // Poster image
            item.fullPosterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.fullPosterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ShimmerPlaceholder(
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    errorWidget: (_, __, ___) => Center(
                      child: Icon(
                        CupertinoIcons.film_fill,
                        color: cs.onSurfaceVariant,
                        size: 32,
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                      CupertinoIcons.film_fill,
                      color: cs.onSurfaceVariant,
                      size: 32,
                    ),
                  ),

            // Bottom gradient
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.88),
                    ],
                  ),
                ),
              ),
            ),

            // Ink ripple
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: const Color(0xFFE50914).withOpacity(0.2),
                  highlightColor: Colors.black12,
                ),
              ),
            ),

            // Rating badge (top-right)
            if (item.voteAverage > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
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
                        size: 11,
                        color: Color(0xFFFFCB45),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.ratingStr,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // SOON badge for unreleased
            if (item.isUnreleased)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'COMING SOON',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // Title at bottom
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: IgnorePointer(
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
            ),
          ],
        ),
      ),
    );
  }
}
