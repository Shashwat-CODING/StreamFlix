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

class DetailScreen extends StatefulWidget {
  final MediaItem item;
  const DetailScreen({super.key, required this.item});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _service = TmdbService();
  MediaDetail? _detail;
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
    setState(() {
      _isFavorite = BookmarkService.isBookmarked(widget.item.id);
    });
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
    if (mounted)
      setState(() {
        _detail = detail;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [const M3Loading(message: 'Loading details...')],
          ),
        ),
      );
    }

    final item =
        _detail ??
        MediaDetail(
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
      backgroundColor: cs.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(item, cs),
          SliverToBoxAdapter(child: _buildContent(item, cs)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(MediaDetail item, ColorScheme cs) {
    final size = MediaQuery.of(context).size;

    return SliverAppBar(
      expandedHeight: size.height * 0.55,
      pinned: true,
      stretch: true,
      backgroundColor: cs.surface,
      scrolledUnderElevation: 0,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.chevron_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14, top: 4, bottom: 4),
          child: GestureDetector(
            onTap: _toggleBookmark,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isFavorite
                        ? cs.primary.withOpacity(0.35)
                        : Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        _isFavorite
                            ? CupertinoIcons.bookmark_fill
                            : CupertinoIcons.bookmark,
                        key: ValueKey(_isFavorite),
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.fullBackdropUrl.isNotEmpty
                  ? item.fullBackdropUrl
                  : item.fullPosterUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: cs.surfaceContainerHigh),
              errorWidget: (_, __, ___) =>
                  Container(color: cs.surfaceContainerHigh),
            ),
            // Gradient layers
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3, 0.6, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    cs.surface.withOpacity(0.5),
                    cs.surface,
                  ],
                ),
              ),
            ),
            // Bottom info
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _badge(item.mediaType == 'tv' ? 'SERIES' : 'MOVIE'),
                      const SizedBox(width: 10),
                      const Icon(
                        CupertinoIcons.star_fill,
                        size: 16,
                        color: Color(0xFFFFCB45),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.ratingStr,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.15),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.8,
                    ),
                  ).animate().fadeIn(delay: 80.ms).slideX(begin: -0.08),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(MediaDetail item, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      bool isPlayable = true;
                      String buttonText = item.mediaType == 'tv'
                          ? 'Select Episode'
                          : 'Watch Now';
                      IconData buttonIcon = item.mediaType == 'tv'
                          ? CupertinoIcons.list_bullet
                          : CupertinoIcons.play_fill;

                      if (item.mediaType == 'movie') {
                        if (item.status != null && item.status != 'Released') {
                          isPlayable = false;
                          buttonText = 'SOON';
                          buttonIcon = CupertinoIcons.clock_fill;
                        } else if (item.releaseDate != null &&
                            item.releaseDate!.isNotEmpty) {
                          try {
                            final release = DateTime.parse(item.releaseDate!);
                            if (release.isAfter(DateTime.now())) {
                              isPlayable = false;
                              buttonText = 'SOON';
                              buttonIcon = CupertinoIcons.clock_fill;
                            }
                          } catch (_) {}
                        }
                      }

                      return FilledButton.icon(
                        onPressed: isPlayable
                            ? () {
                                if (item.mediaType == 'tv') {
                                  _showEpisodeSelector(item, cs);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerScreen(item: item),
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: Icon(buttonIcon, size: 24),
                        label: Text(buttonText),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                          disabledBackgroundColor: cs.surfaceContainerHigh,
                          disabledForegroundColor: cs.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _squareAction(
                  icon: _isFavorite
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.plus,
                  label: _isFavorite ? 'Saved' : 'Save',
                  onTap: _toggleBookmark,
                  cs: cs,
                ),
                const SizedBox(width: 10),
                _squareAction(
                  icon: CupertinoIcons.share,
                  label: 'Share',
                  onTap: () {},
                  cs: cs,
                ),
              ],
            ).animate().fadeIn(delay: 120.ms),

            const SizedBox(height: 28),

            // Info chips row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _infoChip(CupertinoIcons.calendar, item.year, cs),
                  const SizedBox(width: 10),
                  if (item.runtime != null)
                    _infoChip(CupertinoIcons.clock, '${item.runtime}m', cs),
                  if (item.runtime != null) const SizedBox(width: 10),
                  if (item.genres.isNotEmpty)
                    _infoChip(CupertinoIcons.film, item.genres.first, cs),
                  if (item.genres.isNotEmpty && item.genres.length > 1) ...[
                    const SizedBox(width: 10),
                    _infoChip(CupertinoIcons.tag, item.genres[1], cs),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 180.ms),

            const SizedBox(height: 28),

            // Story section
            _sectionLabel('Synopsis', cs),
            const SizedBox(height: 10),
            Text(
              item.overview ?? 'No description available.',
              style: GoogleFonts.inter(
                color: cs.onSurface.withOpacity(0.75),
                fontSize: 15,
                height: 1.65,
                fontWeight: FontWeight.w400,
              ),
            ).animate().fadeIn(delay: 250.ms),

            // Cast
            if (item.cast.isNotEmpty) ...[
              const SizedBox(height: 32),
              _sectionLabel('Cast', cs),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: item.cast.length.clamp(0, 12),
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) {
                    final person = item.cast[i];
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: cs.surfaceContainerHigh,
                            backgroundImage: person.fullProfileUrl.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    person.fullProfileUrl,
                                  )
                                : null,
                            child: person.fullProfileUrl.isEmpty
                                ? Icon(
                                    CupertinoIcons.person_fill,
                                    color: cs.onSurfaceVariant,
                                    size: 22,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 70,
                          child: Text(
                            person.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ).animate().fadeIn(delay: 350.ms),
            ],

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _badge(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE50914).withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _squareAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: cs.onSurface, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String value, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 7),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, ColorScheme cs) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
        letterSpacing: -0.5,
      ),
    );
  }

  void _showEpisodeSelector(MediaDetail item, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => _EpisodeSelectorSheet(tvDetail: item),
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
    final season = await _service.getTvSeasonDetail(
      widget.tvDetail.id,
      _selectedSeason.seasonNumber,
    );
    if (mounted) {
      setState(() {
        _episodes = season?.episodes ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: size.height * 0.88,
          color: Colors.black.withOpacity(0.85),
          child: Column(
            children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Row(
              children: [
                Text(
                  'Episodes',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                // Season Picker
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 0.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TvSeason>(
                      value: _selectedSeason,
                      dropdownColor: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      icon: Icon(
                        CupertinoIcons.chevron_down,
                        color: cs.onSurface,
                        size: 18,
                      ),
                      isDense: true,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                      items: widget.tvDetail.seasons
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text(s.name)),
                          )
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
          const SizedBox(height: 8),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          Expanded(
            child: _loading
                ? const Center(child: M3Loading(message: 'Loading episodes...'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: _episodes.length,
                    itemBuilder: (_, i) {
                      final ep = _episodes[i];
                      final isUpcoming =
                          ep.airDate != null &&
                          ep.airDate!.isAfter(DateTime.now());

                      return InkWell(
                        onTap: isUpcoming
                            ? null
                            : () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerScreen(
                                      item: widget.tvDetail,
                                      season: ep.seasonNumber,
                                      episode: ep.episodeNumber,
                                    ),
                                  ),
                                );
                              },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Opacity(
                            opacity: isUpcoming ? 0.5 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withOpacity(
                                  0.5,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: ep.fullStillUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: ep.fullStillUrl,
                                            width: 100,
                                            height: 58,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 100,
                                            height: 58,
                                            color: cs.surfaceContainerHighest,
                                            child: Icon(
                                              CupertinoIcons.film_fill,
                                              color: cs.onSurfaceVariant,
                                              size: 22,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ep ${ep.episodeNumber}   ${ep.name}',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: cs.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          ep.overview ?? 'No description.',
                                          style: GoogleFonts.inter(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  isUpcoming
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            'SOON',
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: cs.onSurface.withOpacity(
                                                0.6,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          CupertinoIcons.play_circle,
                                          color: cs.primary,
                                          size: 26,
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
