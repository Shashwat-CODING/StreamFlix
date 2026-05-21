import 'dart:ui';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import 'detail_screen.dart';
import 'search_screen.dart';
import '../widgets/ios_widgets.dart';

class AnimeScreen extends StatefulWidget {
  final VoidCallback onSearch;
  const AnimeScreen({super.key, required this.onSearch});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  final _api = ApiService.instance;
  Map<String, List<MediaItem>> _homeData = {};
  List<MediaItem> _trending = [];
  bool _loading = true;

  int _carouselIndex = 0;
  Timer? _carouselTimer;
  final PageController _carouselCtrl = PageController(viewportFraction: 0.9);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _api.getAnimeHome();
    if (mounted) {
      setState(() {
        _homeData = data;
        // Take "Trending Series" or the first category as trending for carousel
        if (data.containsKey('Trending Series')) {
          _trending = data['Trending Series']!;
        } else if (data.isNotEmpty) {
          _trending = data.values.first;
        }
        _loading = false;
      });
      _startCarousel();
    }
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _trending.isEmpty || !_carouselCtrl.hasClients) return;
      final next = (_carouselIndex + 1) % _trending.take(6).length;
      _carouselCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CupertinoPageScaffold(
      child: _loading
          ? const Center(child: IOSLoading(message: 'Gathering the best anime...'))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverNavigationBar(
                  transitionBetweenRoutes: false,
                  largeTitle: Text('Anime', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  backgroundColor: isDark ? const Color(0xCC000000) : const Color(0xCCF2F2F7),
                  border: null,
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.onSearch,
                    child: const Icon(CupertinoIcons.search, size: 24),
                  ),
                ),
                if (_trending.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildCarousel(theme),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = _homeData.keys.elementAt(index);
                      final items = _homeData[category]!;
                      return _buildCategoryGrid(category, items, theme);
                    },
                    childCount: _homeData.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            ),
    );
  }

  Widget _buildCarousel(CupertinoThemeData theme) {
    final items = _trending.take(6).toList();
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;
    final carouselHeight = isDesktop ? 350.0 : 220.0;

    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SizedBox(
              height: carouselHeight,
              child: PageView.builder(
                controller: _carouselCtrl,
                onPageChanged: (i) => setState(() => _carouselIndex = i),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      CupertinoPageRoute(builder: (_) => DetailScreen(item: item)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: item.fullPosterUrl,
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategoryGrid(String title, List<MediaItem> items, CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 200).floor().clamp(2, 8);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(CupertinoIcons.sparkles, size: 20, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridWidth = constraints.maxWidth;
                  final crossAxisCount = (gridWidth / 200).floor().clamp(2, 8);
                  final cellWidth = (gridWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
                  final childAspectRatio = cellWidth / (cellWidth * 1.5 + 72);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: items.length.clamp(0, 10), // Limit per category for home
                    itemBuilder: (context, index) => _AnimeGridCard(item: items[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }
}

class _AnimeGridCard extends StatelessWidget {
  final MediaItem item;
  const _AnimeGridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasImage = item.fullPosterUrl.isNotEmpty;
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(builder: (_) => DetailScreen(item: item)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'anime_grid_${item.id}_${item.extras?['slug']}',
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: item.fullPosterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: CupertinoColors.systemGrey6),
                        errorWidget: (_, __, ___) => Container(
                          color: CupertinoColors.systemGrey6,
                          child: const Icon(CupertinoIcons.play_rectangle),
                        ),
                      )
                    : Container(
                        color: CupertinoColors.systemGrey6,
                        child: const Icon(CupertinoIcons.play_rectangle),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.extras?['quality'] != null || item.extras?['episode'] != null)
            Text(
              '${item.extras?['quality'] ?? ''} ${item.extras?['episode'] != null ? '· Ep ${item.extras?['episode']}' : ''}',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class AnimeSearchScreen extends StatefulWidget {
  const AnimeSearchScreen({super.key});

  @override
  State<AnimeSearchScreen> createState() => _AnimeSearchScreenState();
}

class _AnimeSearchScreenState extends State<AnimeSearchScreen> {
  final _api = ApiService.instance;
  final _controller = TextEditingController();
  List<MediaItem> _results = [];
  bool _searching = false;

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _searching = true);
    final results = await _api.searchAnime(q);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: const Text('Search Anime'),
        trailing: _searching ? const CupertinoActivityIndicator() : null,
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: IOSSearchField(
                    controller: _controller,
                    placeholder: 'Search for anime...',
                    onSubmitted: _doSearch,
                  ),
                ),
                Expanded(
                  child: _results.isEmpty && !_searching
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.search, size: 64, color: CupertinoColors.systemGrey4),
                              const SizedBox(height: 16),
                              Text('Search for your favorite anime', style: TextStyle(color: CupertinoColors.systemGrey)),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final gridWidth = constraints.maxWidth;
                            final crossAxisCount = (gridWidth / 200).floor().clamp(2, 8);
                            final cellWidth = (gridWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
                            final childAspectRatio = cellWidth / (cellWidth * 1.5 + 72);

                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: _results.length,
                              itemBuilder: (context, index) => _AnimeGridCard(item: _results[index]),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
