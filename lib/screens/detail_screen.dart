import 'dart:ui';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/bookmark_service.dart';
import '../services/ad_service.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';
import '../models/api_models.dart';
import '../services/streaming_service.dart';
import 'anime_player_screen.dart';
import 'player_screen.dart';
import '../widgets/mini_player_wrapper.dart';
import '../services/collection_service.dart';
import '../widgets/ios_widgets.dart';

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
      if (widget.item.mediaType == 'anime') {
        detail = await _api.getAnimeDetail(widget.item);
      } else {
        detail = widget.item.mediaType == 'tv'
            ? await _api.getTvDetail(widget.item.id)
            : await _api.getMovieDetail(widget.item.id);
      }
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
      if (widget.item.mediaType == 'anime') {
        _similar = []; // No similar anime for now
        if (mounted) setState(() { _loading = false; });
        return;
      }
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
    final theme = CupertinoTheme.of(context);

    if (_loading) {
      return MiniPlayerWrapper(
        child: CupertinoPageScaffold(
          child: const Center(child: IOSLoading(message: 'Gathering metadata...')),
        ),
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

    return MiniPlayerWrapper(
      child: CupertinoPageScaffold(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DetailHeaderDelegate(
                item: item,
                isFavorite: _isFavorite,
                onBack: () => Navigator.pop(context),
                onBookmark: _toggleBookmark,
                expandedHeight: MediaQuery.of(context).size.height * 0.45,
              ),
            ),
            SliverToBoxAdapter(child: _buildBody(item, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(MediaDetail item, CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MetaItem(icon: CupertinoIcons.star_fill, label: item.ratingStr, color: const Color(0xFFFFCB45)),
              const SizedBox(width: 16),
              _MetaItem(label: item.year),
              const SizedBox(width: 16),
              if ((item.runtime ?? 0) > 0) _MetaItem(label: '${item.runtime}m'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (item.mediaType == 'tv' || (item.mediaType == 'anime' && item.extras?['anime_type'] == 'series')) {
                      _showEpisodeSelector(item);
                    } else {
                      AdService.showRewardedAd(
                        context: context,
                        onComplete: () {
                          if (context.mounted) {
                            if (item.mediaType == 'anime') {
                              Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(
                                builder: (_) => AnimePlayerScreen(
                                  item: item,
                                  slug: item.extras?['slug'] ?? '',
                                  type: 'movie',
                                ),
                              ));
                            } else {
                              Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(
                                builder: (_) => PlayerScreen(item: item),
                              ));
                            }
                          }
                        },
                      );
                    }
                  },
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Icon(
                      (item.mediaType == 'tv' || (item.mediaType == 'anime' && item.extras?['anime_type'] == 'series')) 
                        ? CupertinoIcons.list_bullet 
                        : CupertinoIcons.play_fill, 
                      size: 18, 
                      color: CupertinoColors.white
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (item.mediaType == 'tv' || (item.mediaType == 'anime' && item.extras?['anime_type'] == 'series')) 
                        ? 'Episodes' 
                        : 'Play', 
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: CupertinoColors.white)
                    ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _DetailActionBtn(
                icon: _isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                onPressed: _toggleBookmark,
                active: _isFavorite,
              ),
              _DetailActionBtn(
                icon: CupertinoIcons.share,
                onPressed: () {
                  final url = '${ApiService.websiteUrl}/details?type=${item.mediaType}&id=${item.id}';
                  Share.share('Check out "${item.title}" on Luxa!\n\nWatch here: $url');
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Overview', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            item.overview ?? 'No description available.',
            style: GoogleFonts.outfit(fontSize: 15, color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2, height: 1.5),
          ),
          if (item.cast.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('Top Cast', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: item.cast.length.clamp(0, 10),
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) => _CastMember(cast: item.cast[i]),
              ),
            ),
          ],
          if (_similar.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('Recommendations', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _similar.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final simItem = _similar[i];
                  final hasImage = simItem.fullPosterUrl.isNotEmpty;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => DetailScreen(item: simItem))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: hasImage
                          ? CachedNetworkImage(imageUrl: simItem.fullPosterUrl, fit: BoxFit.cover, width: 120)
                          : Container(
                              width: 120,
                              color: CupertinoColors.systemGrey6,
                              child: const Icon(CupertinoIcons.film),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  void _showEpisodeSelector(MediaDetail item) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _EpisodeSheet(item: item),
    );
  }
}

class _DetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  final MediaDetail item;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final double expandedHeight;

  _DetailHeaderDelegate({
    required this.item,
    required this.isFavorite,
    required this.onBack,
    required this.onBookmark,
    required this.expandedHeight,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = (shrinkOffset / (expandedHeight - 88)).clamp(0.0, 1.0);
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        Opacity(
          opacity: (1 - progress).clamp(0, 1),
          child: item.fullBackdropUrl.isNotEmpty
              ? CachedNetworkImage(imageUrl: item.fullBackdropUrl, fit: BoxFit.cover)
              : Container(color: CupertinoColors.black),
        ),
        // Gradient overlay
        Opacity(
          opacity: (1 - progress).clamp(0, 1),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xCC000000)],
                stops: [0.6, 1.0],
              ),
            ),
          ),
        ),
        
        // Blurred bar when shrunk
        if (progress > 0.1)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10 * progress, sigmaY: 10 * progress),
              child: Container(
                color: theme.barBackgroundColor.withValues(alpha: progress * 0.8),
              ),
            ),
          ),
          
        // Top Bar Content
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onBack,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? CupertinoColors.black.withValues(alpha: 0.3) : CupertinoColors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.back, size: 24, color: CupertinoColors.white),
                    ),
                  ),
                  if (progress > 0.8)
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? CupertinoColors.white : CupertinoColors.black),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ).animate().fadeIn(duration: 200.ms),
                    ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onBookmark,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? CupertinoColors.black.withValues(alpha: 0.3) : CupertinoColors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart, 
                        size: 24, 
                        color: isFavorite ? CupertinoColors.systemRed : CupertinoColors.white
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Large Title at bottom of expanded area
        if (progress < 0.8)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Opacity(
              opacity: (1 - progress * 1.5).clamp(0, 1),
              child: Text(
                item.title,
                style: GoogleFonts.outfit(color: CupertinoColors.white, fontSize: 32, fontWeight: FontWeight.bold),
                maxLines: 2,
              ),
            ),
          ),
      ],
    );
  }

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => 88;

  @override
  bool shouldRebuild(covariant _DetailHeaderDelegate oldDelegate) => true;
}

class _MetaItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;
  const _MetaItem({this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) Icon(icon, size: 14, color: color ?? CupertinoColors.systemGrey),
        if (icon != null) const SizedBox(width: 4),
        Text(label, style: GoogleFonts.outfit(color: CupertinoColors.systemGrey, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DetailActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  const _DetailActionBtn({required this.icon, required this.onPressed, this.active = false});

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? theme.primaryColor.withValues(alpha: 0.1) : CupertinoColors.systemGrey6,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? theme.primaryColor : CupertinoColors.systemGrey, size: 20),
      ),
    );
  }
}

class _CastMember extends StatelessWidget {
  final dynamic cast;
  const _CastMember({required this.cast});

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasImage = cast.fullProfileUrl != null && cast.fullProfileUrl.isNotEmpty;

    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? CupertinoColors.systemGrey6 : CupertinoColors.systemGrey5,
            image: hasImage
                ? DecorationImage(
                    image: CachedNetworkImageProvider(cast.fullProfileUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: !hasImage
              ? Icon(
                  CupertinoIcons.person_fill,
                  size: 30,
                  color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey3,
                )
              : null,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(cast.name, style: GoogleFonts.outfit(fontSize: 12), textAlign: TextAlign.center, maxLines: 2),
        ),
      ],
    );
  }
}

class _EpisodeSheet extends StatefulWidget {
  final MediaDetail item;
  const _EpisodeSheet({required this.item});

  @override
  State<_EpisodeSheet> createState() => _EpisodeSheetState();
}

class _EpisodeSheetState extends State<_EpisodeSheet> {
  int _selectedSeason = 1;
  List<TvEpisode> _episodes = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _loading = true);
    if (widget.item.mediaType == 'anime') {
       // Anime episodes are already loaded in getAnimeDetail
       setState(() {
         _episodes = widget.item.seasons.isNotEmpty ? widget.item.seasons[0].episodes ?? [] : [];
         _loading = false;
       });
       return;
    }
    final season = await ApiService.instance.getTvSeasonDetail(widget.item.id, _selectedSeason);
    if (mounted) {
      setState(() {
        _episodes = season?.episodes ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    
    return GlassBox(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Episodes', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(context), child: const Icon(CupertinoIcons.xmark_circle_fill)),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.item.seasons.length > 1)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.item.seasons.length,
                  itemBuilder: (_, i) {
                    final s = widget.item.seasons[i];
                    final active = _selectedSeason == s.seasonNumber;
                    return CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () {
                        setState(() => _selectedSeason = s.seasonNumber);
                        _loadEpisodes();
                      },
                      child: Text(s.name, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? CupertinoTheme.of(context).primaryColor : CupertinoColors.systemGrey)),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : ListView.separated(
                      itemCount: _episodes.length,
                      separatorBuilder: (_, __) => Container(height: 0.5, color: CupertinoColors.separator),
                      itemBuilder: (_, i) {
                        final ep = _episodes[i];
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: () {
                            Navigator.pop(context);
                            if (widget.item.mediaType == 'anime') {
                              Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(
                                builder: (_) => AnimePlayerScreen(
                                  item: widget.item as MediaDetail,
                                  slug: ep.extras?['slug'] ?? '',
                                  type: 'episode',
                                ),
                              ));
                            } else {
                              Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(
                                builder: (_) => PlayerScreen(
                                  item: widget.item as MediaDetail,
                                  season: _selectedSeason,
                                  episode: ep.episodeNumber,
                                ),
                              ));
                            }
                          },
                          child: Row(
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: ep.fullStillUrl, width: 100, height: 60, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 100, height: 60, color: isDark ? CupertinoColors.systemGrey6 : CupertinoColors.systemGrey))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${ep.episodeNumber}. ${ep.name}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? CupertinoColors.white : CupertinoColors.black)),
                                  const SizedBox(height: 4),
                                  Text(ep.overview ?? '', style: GoogleFonts.outfit(fontSize: 12, color: CupertinoColors.systemGrey), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
