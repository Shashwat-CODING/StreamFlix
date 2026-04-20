import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/bookmark_service.dart';
import '../widgets/m3_loading.dart';
import '../services/ad_service.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';
import '../models/api_models.dart';
import '../services/streaming_service.dart';
import 'player_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kRadius = 16.0;
const _kPosterW = 125.0;
const _kPosterH = 185.0;
const _accent = Color(0xFFE50914);

TextStyle _font(BuildContext context, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double spacing = 0,
  double height = 1.4,
}) {
  final cs = Theme.of(context).colorScheme;
  return GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: weight,
    color: color ?? cs.onSurface,
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
  final _api = ApiService.instance;
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
          ? await _api.getTvDetail(widget.item.id)
          : await _api.getMovieDetail(widget.item.id);
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
          ? await _api.getSimilarTv(widget.item.id)
          : await _api.getSimilarMovies(widget.item.id);
      if (mounted) setState(() { _similar = similar; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : cs.surface;

    if (_loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: M3Loading(message: 'Gathering metadata...')),
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
    final w = MediaQuery.of(context).size.width;
    final paddingH = w > 1000 ? (w - 1000) / 2 : 24.0;
    final subColor = isDark ? Colors.white70 : cs.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: EdgeInsets.fromLTRB(paddingH, 0, paddingH, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Meta info row ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _MetaBadge(
                    icon: CupertinoIcons.star_fill,
                    label: item.ratingStr,
                    color: const Color(0xFFFFCB45),
                  ),
                  _MetaDivider(),
                  _MetaBadge(label: item.year),
                  _MetaDivider(),
                  if ((item.runtime ?? 0) > 0) ...[
                    _MetaBadge(label: '${item.runtime}m'),
                    _MetaDivider(),
                  ],
                  if (item.genres.isNotEmpty)
                    _MetaBadge(label: item.genres.first),
                  if (item.productionCountries.isNotEmpty) ...[
                    _MetaDivider(),
                    _MetaBadge(label: item.productionCountries.first),
                  ],
                ],
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

          const SizedBox(height: 32),

          // ── Action Buttons ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _FullButton(
                  onPressed: () {
                    if (item.mediaType == 'tv') {
                      _showEpisodeSelector(item);
                    } else {
                      AdService.showRewardedAd(
                        context: context,
                        onComplete: () {
                          if (context.mounted) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => PlayerScreen(item: item),
                            ));
                          }
                        },
                      );
                    }
                  },
                  icon: item.mediaType == 'tv' ? CupertinoIcons.square_list : CupertinoIcons.play_fill,
                  label: item.mediaType == 'tv' ? 'View Episodes' : 'Watch Movie',
                  primary: true,
                ),
              ),
              const SizedBox(width: 12),

              _SquareIconButton(
                icon: _isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                onPressed: _toggleBookmark,
                active: _isFavorite,
              ),
              const SizedBox(width: 12),
              _SquareIconButton(
                icon: CupertinoIcons.share,
                onPressed: () {
                  final url = '${ApiService.websiteUrl}/details/${item.mediaType}/${item.id}';
                  Share.share(
                    'Check out "${item.title}" on Drishya!\n\nWatch here: $url',
                    subject: 'Share ${item.title}',
                  );
                },
              ),
            ],
          ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.95, 0.95)),

          const SizedBox(height: 32),

          // ── Synopsis ────────────────────────────────────────────────────
          _SectionTitle('About the ${item.mediaType == 'tv' ? 'Series' : 'Movie'}'),
          const SizedBox(height: 12),
          Text(
            (item.overview?.isNotEmpty ?? false) ? item.overview! : 'No description available for this titles.',
            style: _font(context, size: 15, color: subColor, height: 1.6),
          ).animate().fadeIn(delay: 400.ms),

          // ── Cast ────────────────────────────────────────────────────────
          if (item.cast.isNotEmpty) ...[
            const SizedBox(height: 40),
            _SectionTitle('Top Cast'),
            const SizedBox(height: 16),
            SizedBox(
              height: 115,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: item.cast.length.clamp(0, 15),
                separatorBuilder: (_, _) => const SizedBox(width: 20),
                itemBuilder: (_, i) => _CastCard(cast: item.cast[i]),
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],

          const SizedBox(height: 32),
          const NativeAdWidget(size: NativeAdSize.small), // Second Ad (Small)

          const SizedBox(height: 40),
          const NativeAdWidget(size: NativeAdSize.medium), // First Ad (Medium) - kept from before

          // ── More Like This ──────────────────────────────────────────────
          if (_similar.isNotEmpty) ...[
            const SizedBox(height: 40),
            _SectionTitle('Recommendations'),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _similar.length.clamp(0, 10),
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _SimilarCard(
                  item: _similar[i],
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DetailScreen(item: _similar[i]),
                  )),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
          
          const SizedBox(height: 32),
          BannerAdWidget(), // Third Ad (Banner)
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
      barrierColor: Colors.black.withValues(alpha: 0.8), // Darken background for focus
      useSafeArea: true,
      elevation: 0,
      enableDrag: true,
      builder: (_) => _EpisodeSelectorSheet(
        tvDetail: item,
      ),
    );
  }
}



// ── Components ────────────────────────────────────────────────────────────────

class _MetaBadge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;
  const _MetaBadge({this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final subColor = Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color ?? subColor),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: _font(context, size: 13, weight: FontWeight.w600, color: subColor),
        ),
      ],
    );
  }
}

class _MetaDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4, height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FullButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  const _FullButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: primary ? _accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(_kRadius),
          boxShadow: primary ? [
            BoxShadow(
              color: _accent.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? Colors.white : Theme.of(context).colorScheme.onSurface, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: _font(context, size: 15, weight: FontWeight.w800, color: primary ? Colors.white : Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  const _SquareIconButton({required this.icon, required this.onPressed, this.active = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : cs.onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : cs.onSurface.withValues(alpha: 0.05), width: 0.5),
          ),
        child: Icon(icon, color: active ? _accent : Theme.of(context).colorScheme.onSurface, size: 22),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSerifDisplay(
        fontSize: 22,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: 0.2,
      ),
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
    final size = MediaQuery.of(context).size;
    final h = size.height;
    final w = size.width;
    final paddingH = w > 1000 ? (w - 1000) / 2 : 24.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : Theme.of(context).colorScheme.surface;

    return SliverAppBar(
      expandedHeight: w > 1000 ? h * 0.68 : h * 0.58,
      pinned: true,
      stretch: true,
      backgroundColor: bgColor,
      scrolledUnderElevation: 0,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop with high-quality blur on top
            CachedNetworkImage(
              imageUrl: item.fullBackdropUrl.isNotEmpty ? item.fullBackdropUrl : item.fullPosterUrl,
              fit: BoxFit.cover,
            ),
            
            // Premium Gradient System
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.75, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    bgColor.withValues(alpha: 0.8),
                    bgColor,
                  ],
                ),
              ),
            ),

            // Info Bar
            Positioned(
              left: paddingH, right: paddingH, bottom: 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Premium Poster
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_kRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: -5,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Hero(
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
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutCubic),

                  const SizedBox(width: 20),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TypeTag(item.mediaType == 'tv' ? 'TV SERIES' : 'MOVIE'),
                        const SizedBox(height: 12),
                        Text(
                          item.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 34,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.05,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
                  ),
                ],
              ),
            ),

            // Nav Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: paddingH, right: paddingH,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleGlassBtn(icon: CupertinoIcons.chevron_back, onTap: onBack),
                  Row(
                    children: [
                      _CircleGlassBtn(
                        icon: isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                        onTap: onBookmark,
                        active: isFavorite,
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

class _TypeTag extends StatelessWidget {
  final String text;
  const _TypeTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: _font(context, size: 10, weight: FontWeight.w900, spacing: 1.5, color: Colors.white),
      ),
    );
  }
}

class _CircleGlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _CircleGlassBtn({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: active ? _accent.withValues(alpha: 0.8) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15), width: 1),
            ),
            child: Icon(icon, color: active ? Colors.white : Theme.of(context).colorScheme.onSurface, size: 22),
          ),
        ),
      ),
    );
  }
}

// ── Other components ──────────────────────────────────────────────────────────

class _CastCard extends StatelessWidget {
  final dynamic cast;
  const _CastCard({required this.cast});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withValues(alpha: 0.3), width: 1.5),
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundImage: CachedNetworkImageProvider(cast.fullProfileUrl),
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            cast.name,
            textAlign: TextAlign.center,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: _font(context, size: 12, weight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _SimilarCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _SimilarCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 135,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kRadius),
                child: CachedNetworkImage(
                  imageUrl: item.fullPosterUrl,
                  fit: BoxFit.cover, width: double.infinity,
                  placeholder: (_, _) => Container(color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: _font(context, size: 13, weight: FontWeight.w700),
            ),
            Text(
              item.year,
              style: _font(context, size: 10, color: Colors.white.withValues(alpha: 0.4)),
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
  final void Function(int season, int episode)? onEpisodeSelected;
  const _EpisodeSelectorSheet({required this.tvDetail, this.onEpisodeSelected});

  @override
  State<_EpisodeSelectorSheet> createState() => _EpisodeSelectorSheetState();
}

class _EpisodeSelectorSheetState extends State<_EpisodeSelectorSheet> {
  late TvSeason _selectedSeason;
  List<TvEpisode> _episodes = [];
  bool _loading = false;
  final _api = ApiService.instance;

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
    final season = await _api.getTvSeasonDetail(widget.tvDetail.id, _selectedSeason.seasonNumber);
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
    final bgColor = isDark ? const Color(0xFF0F0F0F) : cs.surface;
    final textColor = isDark ? Colors.white : cs.onSurface;

    return Container(
      height: size.height * 0.9,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.05), width: 1),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
            child: Row(
              children: [
                Text('Episodes', style: GoogleFonts.dmSerifDisplay(fontSize: 28, color: textColor, letterSpacing: 0.5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TvSeason>(
                      value: _selectedSeason,
                      dropdownColor: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      icon: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(CupertinoIcons.chevron_down, color: textColor.withValues(alpha: 0.7), size: 14),
                      ),
                      style: _font(context, size: 14, weight: FontWeight.w700, color: textColor),
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
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: _loading
                ? const Center(child: M3Loading(message: 'Loading your episodes...'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _episodes.length,
                    itemBuilder: (_, i) => _EpisodeTile(
                      episode: _episodes[i],
                      tvDetail: widget.tvDetail,
                      onEpisodeSelected: widget.onEpisodeSelected,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Episode Tile ──────────────────────────────────────────────────────────────

class _EpisodeTile extends StatelessWidget {
  final TvEpisode episode;
  final MediaDetail tvDetail;
  final void Function(int season, int episode)? onEpisodeSelected;
  const _EpisodeTile({required this.episode, required this.tvDetail, this.onEpisodeSelected});

  @override
  Widget build(BuildContext context) {
    final ep = episode;
    final isUpcoming = ep.airDate != null && ep.airDate!.isAfter(DateTime.now());
    final subColor = Colors.white54;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03), // Subtle dark card
        borderRadius: BorderRadius.circular(_kRadius + 4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isUpcoming ? null : () {
          if (onEpisodeSelected != null) {
            Navigator.pop(context); // Close sheet
            onEpisodeSelected!(ep.seasonNumber, ep.episodeNumber);
            return;
          }

          AdService.showRewardedAd(
            context: context,
            onComplete: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => PlayerScreen(
                  item: tvDetail,
                  season: ep.seasonNumber,
                  episode: ep.episodeNumber,
                ),
              ));
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Episode Thumbnail
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: ep.fullStillUrl,
                      width: 130, height: 80, fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: Colors.white.withValues(alpha: 0.05)),
                      errorWidget: (_, _, _) => Container(
                        width: 130, height: 80,
                        color: Colors.white10,
                        child: Icon(CupertinoIcons.film, color: Colors.white24, size: 24),
                      ),
                    ),
                  ),
                  if (isUpcoming)
                    Container(
                      width: 130, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(CupertinoIcons.lock_fill, color: Colors.white70, size: 24),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Episode ${ep.episodeNumber}',
                      style: _font(context, size: 11, weight: FontWeight.w900, color: _accent.withValues(alpha: 0.9), spacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ep.name,
                      style: _font(context, size: 15, weight: FontWeight.w800, color: isUpcoming ? Colors.white38 : Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ep.overview?.isNotEmpty == true ? ep.overview! : 'No description available.',
                      style: _font(context, size: 12, color: subColor, height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Play button removed as requested for a cleaner look
            ],
          ),
        ),
      ),
    );
  }
}



