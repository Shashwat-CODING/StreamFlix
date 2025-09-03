import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:chewie/src/cupertino/cupertino_controls.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'services/media_service.dart';
import 'services/tmdb_service.dart';

void main() {
  runApp(const StreamFlixApp());
}

class StreamFlixApp extends StatelessWidget {
  const StreamFlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STREAMFLIX',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3B30), // Red accent
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS light gray
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF2F2F7),
          foregroundColor: Color(0xFF000000),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF000000),
            fontSize: 34,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3B30),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F2F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3B30), // Red accent
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 34,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1C1C1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3B30),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C1C1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TmdbService _tmdb = TmdbService();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<TmdbItem> _popular = [];
  List<TmdbItem> _results = [];
  bool _loading = true;
  String? _error;
  int _searchPage = 1;
  int _searchTotalPages = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  Future<void> _loadPopular() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _tmdb.popularMovies();
      setState(() => _popular = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _searchPage = 1;
      _searchTotalPages = 1;
    });
    try {
      final r = await _tmdb.searchMultiPaged(q, page: 1);
      setState(() {
        _results = r.items.where((e) => e.mediaType == 'movie' || e.mediaType == 'tv').toList();
        _searchPage = r.page;
        _searchTotalPages = r.totalPages;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    if (_searchCtrl.text.trim().isEmpty) return;
    if (_searchPage >= _searchTotalPages) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final nextPage = _searchPage + 1;
      final r = await _tmdb.searchMultiPaged(_searchCtrl.text.trim(), page: nextPage);
      setState(() {
        _results.addAll(r.items.where((e) => e.mediaType == 'movie' || e.mediaType == 'tv'));
        _searchPage = r.page;
        _searchTotalPages = r.totalPages;
      });
    } catch (_) {} finally {
      setState(() {
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_results.isEmpty) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _openDetails(TmdbItem item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsPage(item: item)));
  }

  void _clearSearch() {
    setState(() {
      _searchCtrl.clear();
      _results = [];
      _error = null;
      _searchPage = 1;
      _searchTotalPages = 1;
    });
  }

  Future<void> _openSearchSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                onSubmitted: (_) {
                  Navigator.pop(ctx);
                  _search();
                },
                decoration: const InputDecoration(
                  hintText: 'Search for movies and TV shows...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _search(); }, child: const Text('Search')),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          if (_results.isNotEmpty)
            IconButton(
              tooltip: 'Back',
              onPressed: _clearSearch,
              icon: const Icon(Icons.arrow_back),
            ),
          const Text('STREAMFLIX', style: TextStyle(
            color: Color(0xFFFF3B30), 
            fontWeight: FontWeight.bold,
            fontSize: 28,
            letterSpacing: -0.5,
          )),
          const Spacer(),
          IconButton(
            tooltip: 'Search',
            onPressed: _openSearchSheet,
            icon: const Icon(Icons.search),
          ),
        ]),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              controller: _scrollCtrl,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final it = _results[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? const Color(0xFF1C1C1E) 
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _openDetails(it),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 80,
                                    height: 120,
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? const Color(0xFF2C2C2E) 
                                        : const Color(0xFFF2F2F7),
                                    child: it.posterUrl != null
                                        ? Image.network(it.posterUrl!, fit: BoxFit.cover)
                                        : Center(child: Icon(
                                            Icons.movie_outlined, 
                                            color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                                            size: 24,
                                          )),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.title, 
                                      style: const TextStyle(
                                        fontSize: 17, 
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      it.mediaType.toUpperCase(), 
                                      style: TextStyle(
                                        fontSize: 13, 
                                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).iconTheme.color?.withOpacity(0.3),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_searchPage < _searchTotalPages)
                    Center(
                      child: ElevatedButton(
                        onPressed: _loadingMore ? null : _loadMore,
                        child: _loadingMore
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Load more'),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: 12),
                ]
                else ...[
                  Text('Popular on StreamFlix', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold) ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_popular.isEmpty)
                    Column(children: [
                      Text('No titles found right now.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadPopular, child: const Text('Retry')),
                    ])
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width < 500 ? 2 : 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _popular.length,
                      itemBuilder: (ctx, i) {
                        final it = _popular[i];
                        return _PosterTile(item: it, onTap: () => _openDetails(it));
                      },
                    ),
                ],
              ]),
            ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.item, required this.onTap});
  final TmdbItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF1C1C1E) 
                    : const Color(0xFFF2F2F7),
                child: item.posterUrl != null
                    ? Image.network(item.posterUrl!, fit: BoxFit.cover)
                    : Center(child: Icon(
                        Icons.movie_outlined, 
                        color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                        size: 32,
                      )),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        Text(item.mediaType.toUpperCase(), style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6))),
      ]),
    );
  }
}

class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key, required this.item});
  final TmdbItem item;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  final MediaService _service = MediaService();
  final TmdbService _tmdb = TmdbService();

  MediaInfo? _info;
  MediaSummary? _summary;
  String? _error;
  bool _loading = false;
  bool _loadingDetails = true;
  Map<String, dynamic>? _details;

  String? _selectedLang;
  int _seasonIndex = 0;
  int _episodeIndex = 0;

  // No embedded player here; navigation goes to dedicated playback page

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _loadingDetails = true;
    });
    final det = await _tmdb.details(mediaType: widget.item.mediaType, tmdbId: widget.item.id!);
    setState(() {
      _details = det;
      _loadingDetails = false;
    });
  }

  String? _getPosterUrl() {
    // First try to get poster from TMDB details
    if (_details != null && _details!['poster_path'] != null) {
      return 'https://image.tmdb.org/t/p/w500${_details!['poster_path']}';
    }
    // Fallback to item's poster
    return widget.item.posterUrl;
  }

  String? _getBackdropUrl() {
    // Get backdrop from TMDB details
    if (_details != null && _details!['backdrop_path'] != null) {
      return 'https://image.tmdb.org/t/p/w1280${_details!['backdrop_path']}';
    }
    return null;
  }

  Future<void> _loadPlayback() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
      _summary = null;
      _selectedLang = null;
    });
    try {
      final imdb = await _tmdb.getImdbId(mediaType: widget.item.mediaType, tmdbId: widget.item.id!);
      if (imdb == null) throw Exception('No IMDb id available');
      final info = await _service.getMediaInfo(id: imdb);
      final summary = _service.summarize(info.playlist);
      setState(() {
        _info = info;
        _summary = summary;
        if (summary.type == 'movie') {
          final langs = (summary.seasons.isNotEmpty ? (summary.seasons.first['lang'] as List?) : null) ?? [];
          _selectedLang = langs.isNotEmpty ? langs.first.toString() : null;
        } else if (summary.type == 'tv') {
          final firstSeasonLangs = (summary.seasons.isNotEmpty ? (summary.seasons.first['lang'] as List?) : null) ?? [];
          _selectedLang = firstSeasonLangs.isNotEmpty ? firstSeasonLangs.first.toString() : null;
        }
      });
    } catch (e) {
      // Primary resolver failed (e.g., MediaError: page not found). Use vidsrc fallback in same player.
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaybackPage(
            url: '',
            title: widget.item.title,
            details: _details,
            referer: null,
            tmdbId: widget.item.id,
            mediaType: widget.item.mediaType,
          ),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _playSelected() async {
    if (_info == null || _summary == null) return;
    final playlist = _info!.playlist;
    String? file;
    try {
      if (_summary!.type == 'movie') {
        if (playlist is List) {
          for (final item in playlist) {
            if (item is Map && item['title']?.toString() == _selectedLang) {
              file = item['file']?.toString();
              break;
            }
          }
        }
      } else if (_summary!.type == 'tv') {
        if (playlist is List && playlist.isNotEmpty) {
          final safeSeasonIndex = _seasonIndex.clamp(0, playlist.length - 1);
          final season = playlist[safeSeasonIndex];
          final eps = (season is Map && season['folder'] is List) ? (season['folder'] as List) : const [];
          if (eps.isNotEmpty) {
            final safeEpisodeIndex = _episodeIndex.clamp(0, eps.length - 1);
            final ep = eps[safeEpisodeIndex];
            final langs = (ep is Map && ep['folder'] is List) ? (ep['folder'] as List) : const [];
            for (final lang in langs) {
              if (lang is Map && lang['title']?.toString() == _selectedLang) {
                file = lang['file']?.toString();
                break;
              }
            }
          }
        }
      }
    } catch (_) {}

    if (file == null || file!.isEmpty) {
      setState(() => _error = 'Could not locate file for selection');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final link = await _service.resolveStreamLink(
        playerDomain: _info!.playerDomain,
        key: _info!.key,
        file: file!,
        referer: _info!.pageUrl,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaybackPage(
            url: link,
            title: widget.item.title,
            details: _details,
            referer: _info!.pageUrl,
            tmdbId: widget.item.id,
            mediaType: widget.item.mediaType,
          ),
        ),
      );
    } catch (e) {
      // Fallback: try vidsrc.cc embed capture using TMDB id
      final tmdbId = widget.item.id;
      if (tmdbId == null) {
        setState(() => _error = e.toString());
      } else {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaybackPage(
              url: '',
              title: widget.item.title,
              details: _details,
              referer: null,
              tmdbId: tmdbId,
              mediaType: widget.item.mediaType,
            ),
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _langControls() {
    if (_summary == null) return const SizedBox.shrink();
    // If primary flow failed and we are going to use vidsrc.cc, hide language controls
    // We infer fallback usage when _error contains MediaError during resolve; otherwise keep controls.
    if (_summary!.type == 'movie') {
      final langs = (_summary!.seasons.isNotEmpty ? (_summary!.seasons.first['lang'] as List?) : null) ?? [];
      if (_selectedLang != null && !langs.contains(_selectedLang)) {
        _selectedLang = langs.isNotEmpty ? langs.first.toString() : null;
      }
      return Row(children: [
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedLang,
            hint: const Text('Language'),
            items: [for (final l in langs) DropdownMenuItem<String>(value: l.toString(), child: Text(l.toString()))],
            onChanged: (v) => setState(() => _selectedLang = v),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: (_selectedLang != null && !_loading) ? _playSelected : null, child: const Text('Play')),
      ]);
    } else {
      final seasons = _info?.playlist is List ? (_info!.playlist as List) : <dynamic>[];
      final clampedSeasonIndex = seasons.isEmpty ? null : _seasonIndex.clamp(0, seasons.length - 1);
      final currentSeason = (clampedSeasonIndex == null) ? null : seasons[clampedSeasonIndex];
      final episodes = (currentSeason is Map && currentSeason['folder'] is List) ? (currentSeason['folder'] as List) : const [];
      final clampedEpisodeIndex = episodes.isEmpty ? null : _episodeIndex.clamp(0, episodes.length - 1);
      final currentEpisode = (clampedEpisodeIndex == null) ? null : episodes[clampedEpisodeIndex];
      final langs = (currentEpisode is Map && currentEpisode['folder'] is List)
          ? (currentEpisode['folder'] as List).map((e) => (e is Map ? e['title']?.toString() : null)).whereType<String>().toList()
          : <String>[];
      if (_selectedLang == null && langs.isNotEmpty) _selectedLang = langs.first;
      if (_selectedLang != null && !langs.contains(_selectedLang)) {
        _selectedLang = langs.isNotEmpty ? langs.first : null;
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: seasons.isEmpty ? null : clampedSeasonIndex,
              items: [for (int i = 0; i < seasons.length; i++) DropdownMenuItem<int>(value: i, child: Text(((seasons[i] is Map ? (seasons[i]['title'] ?? null) : null) ?? 'Season ${i + 1}').toString()))],
              onChanged: seasons.isEmpty
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() {
                        _seasonIndex = v;
                        _episodeIndex = 0;
                        _selectedLang = null;
                      });
                    },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: episodes.isEmpty ? null : clampedEpisodeIndex,
              items: [for (int i = 0; i < episodes.length; i++) DropdownMenuItem<int>(value: i, child: Text((((episodes[i] is Map ? (episodes[i]['title'] ?? null) : null) ?? 'Episode ${i + 1}')).toString()))],
              onChanged: episodes.isEmpty
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() {
                        _episodeIndex = v;
                        _selectedLang = null;
                      });
                    },
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedLang,
              hint: const Text('Language'),
              items: [for (final l in langs) DropdownMenuItem<String>(value: l, child: Text(l))],
              onChanged: (v) => setState(() => _selectedLang = v),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: (_selectedLang != null && !_loading && langs.isNotEmpty) ? _playSelected : null, child: const Text('Play')),
        ]),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Backdrop background
          if (_getBackdropUrl() != null)
            Positioned.fill(
              child: Image.network(
                _getBackdropUrl()!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1C1C1E) 
                      : const Color(0xFFF2F2F7),
                ),
              ),
            )
          else
            Container(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF1C1C1E) 
                  : const Color(0xFFF2F2F7),
            ),
          
          // Dark overlay for better text readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // App bar with back button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Movie details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.item.title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Rating and metadata
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _details != null 
                                        ? '${_details!['vote_average']?.toStringAsFixed(1) ?? 'N/A'}'
                                        : 'N/A',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _details != null 
                                  ? '${_details!['release_date']?.toString().split('-')[0] ?? 'N/A'}'
                                  : 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Movie',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Overview
                        if (_details != null)
                          Text(
                            _details!['overview'] ?? 'No overview available',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          )
                        else if (_loadingDetails)
                          const CircularProgressIndicator(color: Colors.white)
                        else
                          const Text(
                            'Failed to load details',
                            style: TextStyle(color: Colors.white),
                          ),
                        
                        const Spacer(),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _loading ? null : _loadPlayback,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Play'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Language controls (if available)
                        if (_summary != null) _langControls(),
                        
                        // Error display
                        if (_error != null) Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!, 
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaybackPage extends StatefulWidget {
  const PlaybackPage({super.key, required this.url, required this.title, this.details, this.referer, this.tmdbId, this.mediaType});
  final String url; // if empty, we will attempt vidsrc fallback
  final String title;
  final Map<String, dynamic>? details;
  final String? referer;
  final int? tmdbId;
  final String? mediaType; // 'movie' | 'tv'

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends State<PlaybackPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initError = false;
  bool _isLoading = true;
  WebViewController? _webController; // hidden for fallback capture
  bool _hlsCaptured = false;

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty) {
      _initializeDirect(widget.url, referer: widget.referer);
    } else {
      _fallbackToVidsrc();
    }
  }

  Future<void> _initializeDirect(String url, {String? referer}) async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: {
          'User-Agent': _userAgentFallback,
          'Accept': '*/*',
          'Origin': 'https://vidsrc.cc',
          'Referer': referer ?? 'https://vidsrc.cc',
          'Connection': 'keep-alive',
        },
      );
      await _videoController!.initialize();
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        customControls: const CupertinoControls(
          backgroundColor: Color.fromRGBO(20, 20, 20, 0.7),
          iconColor: Colors.white,
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Colors.grey.shade400,
          backgroundColor: Colors.grey.shade300,
        ),
      );
      _isLoading = false;
      setState(() {});
    } catch (_) {
      setState(() { _initError = true; _isLoading = false; });
    }
  }

  static const String _userAgentFallback = 'Mozilla/5.0 (Linux; Android 12; Flutter) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  String? get _embedUrlFallback {
    if (widget.tmdbId == null) return null;
    final typePath = (widget.mediaType == 'tv') ? 'tv' : 'movie';
    return 'https://vidsrc.cc/v2/embed/$typePath/${widget.tmdbId}?autoPlay=true';
  }

  Future<void> _fallbackToVidsrc() async {
    final embed = _embedUrlFallback;
    if (embed == null) {
      setState(() { _initError = true; _isLoading = false; });
      return;
    }
    
    setState(() { _isLoading = true; _initError = false; });
    
    // Use the working approach from the separate player
    final webController = WebViewController();
    webController.setUserAgent(_userAgentFallback);
    webController.setJavaScriptMode(JavaScriptMode.unrestricted);
    webController.setBackgroundColor(Colors.transparent);
    
    webController.addJavaScriptChannel('HLS', onMessageReceived: (JavaScriptMessage message) async {
      if (_hlsCaptured) return;
      final capturedUrl = message.message;
      if (capturedUrl.contains('.m3u8')) {
        _hlsCaptured = true;
        await _initializeDirect(capturedUrl, referer: embed);
        if (mounted) setState(() {});
      }
    });
    
    webController.setNavigationDelegate(NavigationDelegate(onPageFinished: (url) async {
      const js = r"""
        (function(){
          if (window.__hlsHooked) return; window.__hlsHooked = true;
          function send(u){ try { HLS.postMessage(u); } catch(e) {} }
          const origFetch = window.fetch;
          window.fetch = async function(){
            try{
              const req = arguments[0];
              const url = (typeof req === 'string') ? req : (req && req.url ? req.url : '');
              if (url && url.indexOf('.m3u8') !== -1) { send(url); }
            } catch(e){}
            return origFetch.apply(this, arguments);
          };
          const origOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url){
            try { if (typeof url === 'string' && url.indexOf('.m3u8') !== -1) { send(url); } } catch(e){}
            return origOpen.apply(this, arguments);
          };
        })();
      """;
      try { await webController.runJavaScript(js); } catch (_) {}
    }));

    await webController.loadRequest(Uri.parse(embed), headers: const {
      'User-Agent': _userAgentFallback,
      'Referer': 'https://vidsrc.cc',
      'Origin': 'https://vidsrc.cc',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    });

    _webController = webController;

    // Also try direct HTML fetch as backup
    Future.delayed(const Duration(seconds: 6), () async {
      if (mounted && !_hlsCaptured) {
        try {
          final response = await http.get(Uri.parse(embed), headers: const {
            'User-Agent': _userAgentFallback,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
          });
          
          if (response.statusCode == 200) {
            final html = response.body;
            final regex = RegExp(r'https://[^"\s]+\.m3u8[^"\s]*');
            final match = regex.firstMatch(html);
            if (match != null && !_hlsCaptured) {
              _hlsCaptured = true;
              await _initializeDirect(match.group(0)!, referer: embed);
            }
          }
        } catch (_) {}
        
        if (!_hlsCaptured) {
          _initError = true;
          _isLoading = false;
          if (mounted) setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: (_videoController == null || !_videoController!.value.isInitialized || _chewieController == null)
              ? (_initError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Failed to load stream'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              if (widget.url.isEmpty) {
                                _fallbackToVidsrc();
                              } else {
                                _initializeDirect(widget.url, referer: widget.referer);
                              }
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : Stack(children: [
                      const Center(child: CircularProgressIndicator()),
                      if (_webController != null)
                        Positioned.fill(
                          child: Offstage(
                            offstage: true,
                            child: WebViewWidget(controller: _webController!),
                          ),
                        ),
                    ]))
              : Chewie(controller: _chewieController!),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.details != null) ...[
                if ((widget.details!['tagline'] ?? '').toString().isNotEmpty) Text((widget.details!['tagline'] ?? '').toString(), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text((widget.details!['overview'] ?? '').toString()),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class VidsrcFallbackPage extends StatefulWidget {
  const VidsrcFallbackPage({super.key, required this.title, required this.mediaType, required this.tmdbId});
  final String title;
  final String mediaType; // 'movie' | 'tv'
  final int tmdbId;

  @override
  State<VidsrcFallbackPage> createState() => _VidsrcFallbackPageState();
}

class _VidsrcFallbackPageState extends State<VidsrcFallbackPage> {
  static const String _userAgent = 'Mozilla/5.0 (Linux; Android 12; Flutter) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';
  WebViewController? _webController;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _initializationError = false;
  bool _hlsCaptured = false;

  String get _embedUrl {
    final typePath = (widget.mediaType == 'tv') ? 'tv' : 'movie';
    return 'https://vidsrc.cc/v2/embed/$typePath/${widget.tmdbId}?autoPlay=true';
  }

  @override
  void initState() {
    super.initState();
    _setupHiddenWebViewAndLoad();
  }

  Future<String?> _extractHlsUrlFallback() async {
    try {
      final resp = await http.get(
        Uri.parse(_embedUrl),
        headers: const {
          'User-Agent': _userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
        },
      );
      if (resp.statusCode == 200) {
        final html = resp.body;
        final regex = RegExp(r'https://[^"\s]+\.m3u8[^"\s]*');
        final match = regex.firstMatch(html);
        if (match != null) return match.group(0);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _setupHiddenWebViewAndLoad() async {
    setState(() => _isLoading = true);
    final controller = WebViewController()
      ..setUserAgent(_userAgent);
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(Colors.transparent);
    controller.addJavaScriptChannel('HLS', onMessageReceived: (JavaScriptMessage message) async {
      if (_hlsCaptured) return;
      final capturedUrl = message.message;
      if (capturedUrl.contains('.m3u8')) {
        _hlsCaptured = true;
        await _initializePlayer(capturedUrl);
        if (mounted) setState(() {});
      }
    });
    controller.setNavigationDelegate(NavigationDelegate(onPageFinished: (url) async {
      const js = r"""
        (function(){
          if (window.__hlsHooked) return; window.__hlsHooked = true;
          function send(u){ try { HLS.postMessage(u); } catch(e) {} }
          const origFetch = window.fetch;
          window.fetch = async function(){
            try{
              const req = arguments[0];
              const url = (typeof req === 'string') ? req : (req && req.url ? req.url : '');
              if (url && url.indexOf('.m3u8') !== -1) { send(url); }
            } catch(e){}
            return origFetch.apply(this, arguments);
          };
          const origOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url){
            try { if (typeof url === 'string' && url.indexOf('.m3u8') !== -1) { send(url); } } catch(e){}
            return origOpen.apply(this, arguments);
          };
        })();
      """;
      try { await controller.runJavaScript(js); } catch (_) {}
    }));

    await controller.loadRequest(Uri.parse(_embedUrl), headers: const {
      'User-Agent': _userAgent,
      'Referer': 'https://vidsrc.cc',
      'Origin': 'https://vidsrc.cc',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    });
    _webController = controller;

    Future.delayed(const Duration(seconds: 6), () async {
      if (mounted && !_hlsCaptured) {
        final fallbackUrl = await _extractHlsUrlFallback();
        if (fallbackUrl != null && !_hlsCaptured) {
          _hlsCaptured = true;
          await _initializePlayer(fallbackUrl);
        } else {
          _initializationError = true;
          if (mounted) setState(() {});
        }
      }
    });
  }

  Future<void> _initializePlayer(String hlsUrl) async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(hlsUrl),
        httpHeaders: {
          'User-Agent': _userAgent,
          'Accept': '*/*',
          'Origin': 'https://vidsrc.cc',
          'Referer': _embedUrl,
          'Connection': 'keep-alive',
        },
      );
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Colors.grey.shade400,
          backgroundColor: Colors.grey.shade300,
        ),
      );
      _isLoading = false;
      if (mounted) setState(() {});
    } catch (_) {
      _initializationError = true;
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          Center(
            child: _isLoading
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Extracting stream...'),
                    ],
                  )
                : _initializationError
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Failed to load stream'),
                      )
                    : (_chewieController == null || _videoController == null || !_videoController!.value.isInitialized)
                        ? const CircularProgressIndicator()
                        : AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio == 0 ? 16 / 9 : _videoController!.value.aspectRatio,
                            child: Chewie(controller: _chewieController!),
                          ),
          ),
          if (_webController != null)
            Offstage(
              offstage: true,
              child: SizedBox(
                height: 1,
                width: 1,
                child: WebViewWidget(controller: _webController!),
              ),
            ),
        ],
      ),
    );
  }
}
