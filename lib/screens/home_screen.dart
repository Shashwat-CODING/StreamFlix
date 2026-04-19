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
import '../services/api_service.dart';
import '../widgets/shimmer_placeholder.dart';
import 'detail_screen.dart';
import '../services/watch_history.dart';
import 'search_screen.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';

// ── Design tokens (shared with DetailScreen) ──────────────────────────────────

const _accent = Color(0xFFE50914);
const _kRadius = 14.0;
const _kRadiusLg = 20.0;
const _white = Colors.white;

TextStyle _font({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = _white,
  double spacing = 0,
  double height = 1.4,
}) =>
    GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
    );

// ── Home Screen ───────────────────────────────────────────────────────────────

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
  final PageController _heroController = PageController(viewportFraction: 0.88);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: M3Loading(message: 'Curating the best content for you...'))
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
                      SliverAppBar(
                        floating: true,
                        pinned: true,
                        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        toolbarHeight: 56,
                        title: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/logo.png',
                                width: 24,
                                height: 24,
                              ).animate().fadeIn(duration: 400.ms),
                              const SizedBox(width: 8),
                              RichText(
                                text: TextSpan(children: [
                                  TextSpan(
                                    text: 'Drishya',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface, letterSpacing: -0.5),
                                  ),
                                  TextSpan(
                                    text: '',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 20, fontWeight: FontWeight.bold, color: _accent, letterSpacing: -0.5),
                                  ),
                                ]),
                              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                            ],
                          ),
                        ),
                        actions: [
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: IconButton(
                              onPressed: () {
                                if (widget.onSearch != null) {
                                  widget.onSearch!();
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const SearchScreen()),
                                  );
                                }
                              },
                              icon: Icon(CupertinoIcons.search,
                                  color: cs.onSurface, size: 24),
                            ).animate().fadeIn(delay: 200.ms),
                          ),
                        ],
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
                            const SizedBox(height: 4),
                            _buildContinueWatching(),
                            const NativeAdWidget(size: NativeAdSize.small), // First Ad (Small)
                            _ContentSection(
                              title: 'Trending Now',
                              icon: CupertinoIcons.flame_fill,
                              iconColor: const Color(0xFFFF6240),
                              items: _trending,
                              delay: 0,
                              onTap: _openDetail,
                            ),
                            const NativeAdWidget(size: NativeAdSize.medium), // Second Ad (Medium)
                            _ContentSection(
                              title: 'Now Playing',
                              icon: CupertinoIcons.play_rectangle_fill,
                              iconColor: _accent,
                              items: _nowPlayingMovies,
                              delay: 40,
                              onTap: _openDetail,
                            ),
                            const NativeAdWidget(size: NativeAdSize.small), // Third Ad (Small)
                            _ContentSection(
                              title: 'Popular Movies',
                              icon: CupertinoIcons.film_fill,
                              iconColor: const Color(0xFF8B6FCA),
                              items: _popularMovies,
                              delay: 80,
                              onTap: _openDetail,
                            ),
                            BannerAdWidget(), // Fourth Ad (Banner)
                            _ContentSection(
                              title: 'Anime Hits',
                              icon: CupertinoIcons.sparkles,
                              iconColor: const Color(0xFFFF8C42),
                              items: _animeMovies,
                              delay: 120,
                              onTap: _openDetail,
                            ),
                            const NativeAdWidget(size: NativeAdSize.medium), // Fifth Ad (Medium)
                            const SizedBox(height: 110),
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

  Widget _buildContinueWatching() {
    final history = WatchHistory.history;
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
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
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

// ── Top Bar ───────────────────────────────────────────────────────────────────



// ── Hero Carousel ─────────────────────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    final screenH = MediaQuery.of(context).size.height;
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final cardH = isDesktop
        ? (screenH * 0.48).clamp(300.0, 440.0)
        : screenH * 0.46;

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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: _HeroCard(
                item: items[i],
                onTap: () => onTap(items[i]),
                cs: cs,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            final active = i == heroIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.only(right: 5),
              width: active ? 20 : 5,
              height: 4,
              decoration: BoxDecoration(
                color: active ? _accent : cs.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _HeroCard(
      {required this.item, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              key: ValueKey(item.id),
              imageUrl: item.fullBackdropUrl.isNotEmpty
                  ? item.fullBackdropUrl
                  : item.fullPosterUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  Container(color: cs.surfaceContainerHigh),
              errorWidget: (_, _, _) =>
                  Container(color: cs.surfaceContainerHigh),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1.0],
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.95)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _TypeBadge(item.mediaType == 'tv' ? 'SERIES' : 'MOVIE'),
                      if (item.voteAverage > 0) ...[
                        const SizedBox(width: 12),
                        const Icon(CupertinoIcons.star_fill,
                            size: 14, color: Color(0xFFFFCB45)),
                        const SizedBox(width: 4),
                        Text(item.ratingStr,
                            style:
                                _font(size: 14, weight: FontWeight.w800)),
                      ],
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(item.year,
                            style: _font(
                                size: 11,
                                color: Colors.white,
                                weight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    style: GoogleFonts.dmSerifDisplay(
                        color: _white, fontSize: 32, height: 1.1, letterSpacing: -0.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroBtn.primary(
                          label: item.isUnreleased ? 'Coming Soon' : 'Play',
                          icon: item.isUnreleased
                              ? CupertinoIcons.calendar
                              : CupertinoIcons.play_fill,
                          onTap: onTap,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroBtn.ghost(
                          label: 'Details',
                          icon: CupertinoIcons.info_circle,
                          onTap: onTap,
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
  }
}

// ── Hero Buttons ──────────────────────────────────────────────────────────────

class _HeroBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _HeroBtn._({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  factory _HeroBtn.primary(
          {required String label,
          required IconData icon,
          required VoidCallback onTap}) =>
      _HeroBtn._(label: label, icon: icon, onTap: onTap, primary: true);

  factory _HeroBtn.ghost(
          {required String label,
          required IconData icon,
          required VoidCallback onTap}) =>
      _HeroBtn._(label: label, icon: icon, onTap: onTap, primary: false);

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE50914),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _white, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: _font(size: 14, weight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: Colors.white.withValues(alpha: 0.95), size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: _font(
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.95),
                      weight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Type Badge ────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  const _TypeBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: _font(
                  size: 10, color: Colors.white, weight: FontWeight.w900, spacing: 1.2)),
        ),
      ),
    );
  }
}

// ── Continue Watching Card ────────────────────────────────────────────────────

class _ContinueCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _ContinueCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasProgress = item.position != null &&
        item.duration != null &&
        item.duration! > 0;
    final progress = hasProgress
        ? (item.position! / item.duration!).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadius),
        child: SizedBox(
          width: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.fullBackdropUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.fullBackdropUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(color: cs.surfaceContainerHigh),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1.0],
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              const Center(
                child: Icon(CupertinoIcons.play_fill,
                    color: Colors.white70, size: 28),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.title,
                        style:
                            _font(size: 12, weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (hasProgress) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(_accent),
                          minHeight: 2.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style:
                GoogleFonts.dmSerifDisplay(fontSize: 20, color: cs.onSurface),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: Text('See all',
                style: _font(
                    size: 13,
                    color: cs.primary,
                    weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Content Section ───────────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<MediaItem> items;
  final int delay;
  final ValueChanged<MediaItem> onTap;

  const _ContentSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, icon: icon, iconColor: iconColor),
        const SizedBox(height: 14),
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length.clamp(0, 12),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 155,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) => _PosterCard(
                item: items[i],
                onTap: () => onTap(items[i]),
              ).animate().fadeIn(
                    delay: (i * 28).ms,
                    duration: 280.ms,
                  ),
            ),
          )
        else
          SizedBox(
            height: 218,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _PosterCard(
                item: items[i],
                onTap: () => onTap(items[i]),
              ).animate().fadeIn(
                    delay: (i * 35).ms,
                    duration: 320.ms,
                  ),
            ),
          ),
        const SizedBox(height: 32),
      ],
    ).animate().fadeIn(delay: delay.ms, duration: 400.ms);
  }
}

// ── Poster Card ───────────────────────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _PosterCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: cs.surfaceContainerHigh),
            if (item.fullPosterUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: item.fullPosterUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ShimmerPlaceholder(
                  width: double.infinity,
                  height: double.infinity,
                ),
                errorWidget: (_, _, _) => Center(
                  child: Icon(CupertinoIcons.film_fill,
                      color: cs.onSurfaceVariant, size: 28),
                ),
              )
            else
              Center(
                child: Icon(CupertinoIcons.film_fill,
                    color: cs.onSurfaceVariant, size: 28),
              ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD000000)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: _accent.withValues(alpha: 0.15),
                  highlightColor: Colors.black12,
                ),
              ),
            ),
            if (item.voteAverage > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.star_fill,
                          size: 10, color: Color(0xFFFFCB45)),
                      const SizedBox(width: 3),
                      Text(item.ratingStr,
                          style: _font(
                              size: 10,
                              weight: FontWeight.w700,
                              color: _white)),
                    ],
                  ),
                ),
              ),
            if (item.isUnreleased)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('SOON',
                      style: _font(
                          size: 9,
                          weight: FontWeight.w800,
                          spacing: 0.6,
                          color: _white)),
                ),
              ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: IgnorePointer(
                child: Text(
                  item.title,
                  style:
                      _font(size: 12, weight: FontWeight.w600, height: 1.3),
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
