import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../services/bookmark_service.dart';
import '../services/watch_history.dart';
import '../widgets/m3_loading.dart';
import 'player_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kRadius = 14.0;
const _kPosterW = 120.0;
const _kPosterH = 178.0;
const _accent = Color(0xFFE50914);

TextStyle _font(BuildContext context, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double spacing = 0,
  double height = 1.4,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final defaultColor = isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
  return GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: weight,
    color: color ?? defaultColor,
    letterSpacing: spacing,
    height: height,
  );
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class DetailScreen extends StatefulWidget {
  final MediaItem item;
  const DetailScreen({super.key, required this.item});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _service = TmdbService();
  MediaDetail? _detail;
  List<MediaItem> _similar = [];
  bool _loading = true;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = BookmarkService.isBookmarked(widget.item.id);
    _load();
  }

  void _toggleBookmark() {
    BookmarkService.toggleBookmark(widget.item);
    setState(() => _isFavorite = BookmarkService.isBookmarked(widget.item.id));
  }

  Future<void> _load() async {
    MediaDetail? detail;
    try {
      detail = widget.item.mediaType == 'tv'
          ? await _service.getTvDetail(widget.item.id)
          : await _service.getMovieDetail(widget.item.id);
    } catch (e) {
      debugPrint('Error loading details: $e');
    }
    if (mounted) {
      setState(() => _detail = detail);
      _loadSimilar();
    }
  }

  Future<void> _loadSimilar() async {
    try {
      final similar = widget.item.mediaType == 'tv'
          ? await _service.getSimilarTv(widget.item.id)
          : await _service.getSimilarMovies(widget.item.id);
      if (mounted) setState(() { _similar = similar; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : cs.surface;

    if (_loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: M3Loading(message: 'Loading…')),
      );
    }

    final item = _detail ?? MediaDetail(
      id: widget.item.id,
      title: widget.item.title,
      overview: widget.item.overview ?? '',
      posterPath: widget.item.posterPath ?? '',
      backdropPath: widget.item.backdropPath ?? '',
      releaseDate: widget.item.releaseDate ?? '',
      voteAverage: widget.item.voteAverage,
      mediaType: widget.item.mediaType,
      genres: [],
      cast: [],
    );

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _HeroAppBar(
            item: item,
            isFavorite: _isFavorite,
            onBack: () => Navigator.pop(context),
            onBookmark: _toggleBookmark,
          ),
          SliverToBoxAdapter(child: _buildBody(item, cs, isDark)),
        ],
      ),
    );
  }

  Widget _buildBody(MediaDetail item, ColorScheme cs, bool isDark) {
    final subColor = isDark ? Colors.white70 : cs.onSurface.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Meta chips row ──────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _MetaChip(icon: CupertinoIcons.star_fill, label: item.ratingStr, accent: true),
                const SizedBox(width: 8),
                _MetaChip(icon: CupertinoIcons.calendar, label: item.year),
                const SizedBox(width: 8),
                if ((item.runtime ?? 0) > 0)
                  _MetaChip(icon: CupertinoIcons.clock, label: '${item.runtime}m'),
                if ((item.runtime ?? 0) > 0) const SizedBox(width: 8),
                if (item.genres.isNotEmpty)
                  _MetaChip(icon: CupertinoIcons.tag, label: item.genres.first),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 24),

          // ── Quick actions ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActionButton(
                icon: _isFavorite ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                label: _isFavorite ? 'Saved' : 'Save',
                onTap: _toggleBookmark,
                active: _isFavorite,
              ),
              const SizedBox(width: 14),
              _ActionButton(
                icon: CupertinoIcons.share,
                label: 'Share',
                onTap: () {},
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (item.mediaType == 'tv') {
                            _showEpisodeSelector(item);
                          } else {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => PlayerScreen(item: item),
                            ));
                          }
                        },
                        icon: Icon(
                          item.mediaType == 'tv' ? CupertinoIcons.list_bullet : CupertinoIcons.play_fill,
                          size: 18,
                        ),
                        label: Text(
                          item.mediaType == 'tv' ? 'Episodes' : 'Watch Now',
                          maxLines: 1,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_kRadius),
                          ),
                          textStyle: _font(context, size: 14, weight: FontWeight.w700, spacing: 0.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(' ', style: _font(context, size: 11)),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 32),

          // ── Synopsis ────────────────────────────────────────────────────
          _SectionTitle('Synopsis'),
          const SizedBox(height: 10),
          Text(
            (item.overview?.isNotEmpty ?? false) ? item.overview! : 'No description available.',
            style: _font(context, size: 14.5, color: subColor, height: 1.7),
          ).animate().fadeIn(delay: 250.ms),

          // ── Cast ────────────────────────────────────────────────────────
          if (item.cast.isNotEmpty) ...[
            const SizedBox(height: 36),
            _SectionTitle('Cast'),
            const SizedBox(height: 14),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: item.cast.length.clamp(0, 15),
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) => _CastCard(cast: item.cast[i]),
              ),
            ),
          ],

          // ── More Like This ──────────────────────────────────────────────
          if (_similar.isNotEmpty) ...[
            const SizedBox(height: 36),
            _SectionTitle('More Like This'),
            const SizedBox(height: 14),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _similar.length.clamp(0, 10),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _SimilarCard(
                  item: _similar[i],
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DetailScreen(item: _similar[i]),
                  )),
                ),
              ),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _showEpisodeSelector(MediaDetail item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _EpisodeSelectorSheet(tvDetail: item),
    );
  }
}

// ── Hero App Bar ──────────────────────────────────────────────────────────────

class _HeroAppBar extends StatelessWidget {
  final MediaDetail item;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onBookmark;

  const _HeroAppBar({
    required this.item,
    required this.isFavorite,
    required this.onBack,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : cs.surface;

    return SliverAppBar(
      expandedHeight: h * 0.52,
      pinned: true,
      stretch: true,
      backgroundColor: bgColor,
      scrolledUnderElevation: 0,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop
            CachedNetworkImage(
              imageUrl: item.fullBackdropUrl.isNotEmpty ? item.fullBackdropUrl : item.fullPosterUrl,
              fit: BoxFit.cover,
            ),

            // Bottom gradient — deep fade into bg
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.72, 1.0],
                  colors: [
                    const Color(0x55000000),
                    Colors.transparent,
                    bgColor.withOpacity(0.72),
                    bgColor,
                  ],
                ),
              ),
            ),

            // Top gradient for icon legibility
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.25],
                  colors: [Color(0x88000000), Colors.transparent],
                ),
              ),
            ),

            // Poster + title block
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Hero(
                    tag: 'poster-${item.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_kRadius),
                      child: CachedNetworkImage(
                        imageUrl: item.fullPosterUrl,
                        width: _kPosterW,
                        height: _kPosterH,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ).animate().scale(duration: 380.ms, curve: Curves.easeOutBack),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.mediaType == 'tv' ? 'SERIES' : 'MOVIE',
                            style: _font(context, size: 9.5, weight: FontWeight.w700, spacing: 1.2),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 26,
                            color: isDark ? Colors.white : cs.onSurface,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 180.ms).slideX(begin: 0.06, curve: Curves.easeOut),
                  ),
                ],
              ),
            ),

            // Nav buttons
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavBtn(icon: CupertinoIcons.chevron_back, onTap: onBack),
                  _NavBtn(
                    icon: isFavorite ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                    onTap: onBookmark,
                    active: isFavorite,
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

// ── Nav Button ────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _NavBtn({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: active ? _accent.withOpacity(0.3) : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;
  const _MetaChip({required this.icon, required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final subColor = isDark ? Colors.white70 : cs.onSurface.withOpacity(0.7);
    final dimColor = isDark ? Colors.white38 : cs.onSurface.withOpacity(0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.07) : cs.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : cs.onSurface.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent ? const Color(0xFFFFCB45) : dimColor),
          const SizedBox(width: 6),
          Text(label, style: _font(context, size: 12.5, weight: FontWeight.w600, color: subColor)),
        ],
      ),
    );
  }
}

// ── Square Action Button ──────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final subColor = isDark ? Colors.white38 : cs.onSurface.withOpacity(0.38);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: active ? _accent.withOpacity(0.18) : (isDark ? Colors.white.withOpacity(0.07) : cs.onSurface.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(
                color: active ? _accent.withOpacity(0.4) : (isDark ? Colors.white.withOpacity(0.08) : cs.onSurface.withOpacity(0.1)),
                width: 0.5,
              ),
            ),
            child: Icon(icon, color: active ? _accent : (isDark ? Colors.white : cs.onSurface), size: 20),
          ),
          const SizedBox(height: 7),
          Text(label, style: _font(context, size: 11, color: subColor, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Text(text, style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: textColor));
  }
}

// ── Cast Card ─────────────────────────────────────────────────────────────────

class _CastCard extends StatelessWidget {
  final dynamic cast;
  const _CastCard({required this.cast});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final subColor = isDark ? Colors.white70 : cs.onSurface.withOpacity(0.7);

    return SizedBox(
      width: 72,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: CachedNetworkImage(
              imageUrl: cast.fullProfileUrl,
              width: 64, height: 64, fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: isDark ? Colors.white10 : cs.onSurface.withOpacity(0.05),
                child: Icon(CupertinoIcons.person, size: 24, color: isDark ? Colors.white24 : cs.onSurface.withOpacity(0.1)),
              ),
              errorWidget: (_, __, ___) => Container(
                color: isDark ? Colors.white10 : cs.onSurface.withOpacity(0.05),
                child: Icon(CupertinoIcons.person_fill, size: 24, color: isDark ? Colors.white24 : cs.onSurface.withOpacity(0.1)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cast.name,
            textAlign: TextAlign.center,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: _font(context, size: 11, color: subColor, weight: FontWeight.w500, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ── Similar Card ──────────────────────────────────────────────────────────────

class _SimilarCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _SimilarCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kRadius),
                child: CachedNetworkImage(
                  imageUrl: item.fullPosterUrl,
                  fit: BoxFit.cover, width: double.infinity,
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? Colors.white10 : Colors.black12,
                    child: const Icon(CupertinoIcons.film, color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: _font(context, size: 12, color: subColor, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Episode Selector ──────────────────────────────────────────────────────────

class _EpisodeSelectorSheet extends StatefulWidget {
  final MediaDetail tvDetail;
  const _EpisodeSelectorSheet({required this.tvDetail});

  @override
  State<_EpisodeSelectorSheet> createState() => _EpisodeSelectorSheetState();
}

class _EpisodeSelectorSheetState extends State<_EpisodeSelectorSheet> {
  late TvSeason _selectedSeason;
  List<TvEpisode> _episodes = [];
  bool _loading = false;
  final _service = TmdbService();

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.tvDetail.seasons.firstWhere(
      (s) => s.seasonNumber > 0,
      orElse: () => widget.tvDetail.seasons.first,
    );
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _loading = true);
    final season = await _service.getTvSeasonDetail(widget.tvDetail.id, _selectedSeason.seasonNumber);
    if (mounted) {
      setState(() {
        _episodes = season?.episodes ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bgColor = isDark ? const Color(0xEE0F0F0F) : cs.surface.withOpacity(0.95);
    final textColor = isDark ? Colors.white : cs.onSurface;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: size.height * 0.88,
          color: bgColor,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    Text('Episodes', style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: textColor)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.08) : cs.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : cs.onSurface.withOpacity(0.1), width: 0.5),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TvSeason>(
                          value: _selectedSeason,
                          dropdownColor: isDark ? const Color(0xFF1A1A1A) : cs.surface,
                          borderRadius: BorderRadius.circular(14),
                          icon: Icon(CupertinoIcons.chevron_down, color: isDark ? Colors.white70 : cs.onSurface, size: 14),
                          isDense: true,
                          style: _font(context, size: 13, weight: FontWeight.w600),
                          items: widget.tvDetail.seasons
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                              .toList(),
                          onChanged: (s) {
                            if (s != null) {
                              setState(() => _selectedSeason = s);
                              _loadEpisodes();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.06), height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: M3Loading(message: 'Loading episodes…'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: _episodes.length,
                        itemBuilder: (_, i) => _EpisodeTile(episode: _episodes[i], tvDetail: widget.tvDetail),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Episode Tile ──────────────────────────────────────────────────────────────

class _EpisodeTile extends StatelessWidget {
  final TvEpisode episode;
  final MediaDetail tvDetail;
  const _EpisodeTile({required this.episode, required this.tvDetail});

  @override
  Widget build(BuildContext context) {
    final ep = episode;
    final isUpcoming = ep.airDate != null && ep.airDate!.isAfter(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final subColor = isDark ? Colors.white38 : cs.onSurface.withOpacity(0.4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: isUpcoming ? 0.45 : 1.0,
        child: InkWell(
          onTap: isUpcoming ? null : () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PlayerScreen(item: tvDetail, season: ep.seasonNumber, episode: ep.episodeNumber),
            ));
          },
          borderRadius: BorderRadius.circular(_kRadius),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : cs.onSurface.withOpacity(0.03),
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : cs.onSurface.withOpacity(0.05), width: 0.5),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ep.fullStillUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: ep.fullStillUrl, width: 96, height: 56, fit: BoxFit.cover)
                      : Container(
                          width: 96, height: 56,
                          color: isDark ? Colors.white10 : cs.onSurface.withOpacity(0.05),
                          child: Icon(CupertinoIcons.film_fill, color: isDark ? Colors.white24 : cs.onSurface.withOpacity(0.2), size: 20),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ep ${ep.episodeNumber}  ·  ${ep.name}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: _font(context, size: 13, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(ep.overview ?? 'No description.', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: _font(context, size: 12, color: subColor, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isUpcoming
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : cs.onSurface.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('SOON', style: _font(context, size: 9, weight: FontWeight.w700, color: subColor, spacing: 0.8)),
                      )
                    : const Icon(CupertinoIcons.play_circle_fill, color: _accent, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}