import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/m3_loading.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../widgets/shimmer_placeholder.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SearchScreen({super.key, this.onBack});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _service = TmdbService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<MediaItem> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  Timer? _debounce;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    // Auto-focus after frame
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    try {
      final results = await _service.search(q);
      if (mounted)
        setState(() {
          _results = results;
          _loading = false;
          _hasSearched = true;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MediaItem> get _filteredResults {
    if (_selectedFilter == 'all') return _results;
    return _results.where((m) => m.mediaType == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(cs)),
            SliverToBoxAdapter(child: _buildFilters(cs)),
            _buildResultsSliver(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh.withOpacity(0.9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: cs.primary.withOpacity(0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(12),
                  icon: Icon(
                    CupertinoIcons.chevron_back,
                    size: 22,
                    color: cs.onSurface,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onChanged,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search for movies, TV shows...',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                    padding: const EdgeInsets.all(12),
                    icon: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 20,
                      color: cs.onSurfaceVariant.withOpacity(0.6),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(
                      CupertinoIcons.search,
                      color: cs.primary.withOpacity(0.7),
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.1, curve: Curves.easeOut);
  }

  Widget _buildFilters(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Expanded(child: _uniqueFilterTab('all', 'All Content', cs)),
            const SizedBox(width: 4),
            Expanded(child: _uniqueFilterTab('movie', 'Movies', cs)),
            const SizedBox(width: 4),
            Expanded(child: _uniqueFilterTab('tv', 'TV Series', cs)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, curve: Curves.easeOut);
  }

  Widget _uniqueFilterTab(String id, String label, ColorScheme cs) {
    final selected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected
                ? cs.onPrimary
                : cs.onSurfaceVariant.withOpacity(0.6),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSliver(ColorScheme cs) {
    if (_loading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [const M3Loading(message: 'Searching...')],
          ),
        ),
      );
    }
    if (!_hasSearched) {
      return SliverFillRemaining(hasScrollBody: false, child: _buildEmpty(cs));
    }
    if (_filteredResults.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildNoResults(cs),
      );
    }

    final list = _filteredResults;
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (width > 1200) {
      crossAxisCount = 5;
    } else if (width > 900) {
      crossAxisCount = 4;
    } else if (width > 600) {
      crossAxisCount = 3;
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _buildResultCard(list[i], i, cs),
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _buildResultCard(MediaItem item, int index, ColorScheme cs) {
    return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: cs.surfaceContainerHigh,
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 0.5,
              ),
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
                item.fullPosterUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.fullPosterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ShimmerPlaceholder(
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(
                            CupertinoIcons.film,
                            color: cs.primary.withOpacity(0.3),
                            size: 32,
                          ),
                        ),
                      )
                    : Container(color: cs.surfaceContainerHighest),
                // Gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.95),
                        ],
                        stops: const [0.5, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                // Type badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (item.mediaType == 'tv'
                                  ? const Color(0xFF5AC8FA)
                                  : cs.primary)
                              .withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.mediaType == 'tv' ? 'TV' : 'MOVIE',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                // Bottom info
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          shadows: [
                            const Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.star_fill,
                                  size: 10,
                                  color: Color(0xFFFFD700),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.voteAverage > 0
                                      ? item.voteAverage.toStringAsFixed(1)
                                      : 'NR',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
        )
        .animate(delay: (index % 12 * 40).ms)
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child:
          Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.search,
                      size: 56,
                      color: cs.primary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Explore StreamFlix',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 22,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Discover thousands of movies and TV shows from around the world.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: cs.onSurfaceVariant.withOpacity(0.7),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              )
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(
                begin: const Offset(0.95, 0.95),
                curve: Curves.easeOutBack,
              ),
    );
  }

  Widget _buildNoResults(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.errorContainer.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.search_circle,
              size: 60,
              color: cs.onSurfaceVariant.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No matches found',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or filters.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: cs.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ],
      ).animate().fadeIn().shake(duration: 400.ms),
    );
  }
}
