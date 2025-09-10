import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http;
import 'services/media_service.dart';
import 'services/tmdb_service.dart';
import 'player/stream_resolution.dart';
import 'player/server_direct.dart';
import 'player/server_hlstr.dart';
import 'player/server_vidsrc.dart';
import 'services/library_service.dart';
import 'widgets/poster_tile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
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
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0; // 0 = home, 1 = search, 2 = library

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(children: [
        IndexedStack(
          index: _index,
          children: const [HomePage(), SearchPage(), LibraryPage()],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: NavigationBar(
                  height: 64,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                    NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Search'),
                    NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Library'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TmdbService _tmdb = TmdbService();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<TmdbItem> _results = [];
  bool _loading = false;
  String? _error;
  int _searchPage = 1;
  int _searchTotalPages = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_results.isEmpty) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
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
        _results = r.items.where((e) => e.mediaType == 'movie').toList();
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
    setState(() { _loadingMore = true; });
    try {
      final nextPage = _searchPage + 1;
      final r = await _tmdb.searchMultiPaged(_searchCtrl.text.trim(), page: nextPage);
      setState(() {
        _results.addAll(r.items.where((e) => e.mediaType == 'movie'));
        _searchPage = r.page;
        _searchTotalPages = r.totalPages;
      });
    } catch (_) {} finally {
      setState(() { _loadingMore = false; });
    }
  }

  void _openDetails(TmdbItem item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsPage(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(hintText: 'Search for movies and TV shows...'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_results.isEmpty && _error == null)
              ? const Center(child: Text('Search something to begin'))
              : SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width >= 1500 ? 6 : MediaQuery.of(context).size.width >= 1100 ? 5 : MediaQuery.of(context).size.width >= 900 ? 4 : MediaQuery.of(context).size.width >= 700 ? 3 : 2,
                            childAspectRatio: 0.66,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final it = _results[i];
                            return PosterTile(item: it, onTap: () => _openDetails(it));
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
                          ),
                      ]),
                    ),
                  ),
                ),
    );
  }
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
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
                  // Hero header
                  Container(
                    width: double.infinity,
                    height: 320,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Unlimited movies, TV shows, and more.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Watch anywhere. It\'s free.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                        crossAxisCount: MediaQuery.of(context).size.width >= 1800
                            ? 6
                            : MediaQuery.of(context).size.width >= 1500
                                ? 5
                                : MediaQuery.of(context).size.width >= 1200
                                    ? 4
                                    : MediaQuery.of(context).size.width >= 800
                                        ? 3
                                        : 2,
                        childAspectRatio: 0.66,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _popular.length,
                      itemBuilder: (ctx, i) {
                        final it = _popular[i];
                        return PosterTile(item: it, onTap: () => _openDetails(it));
                      },
                    ),
                ],
                  ]),
                ),
              ),
            ),
    );
  }
}

// moved to widgets/poster_tile.dart and services/library_service.dart

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    final lib = LibraryService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: AnimatedBuilder(
        animation: lib,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Watch Later', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (lib.watchLater.isEmpty)
                    Text('No items saved yet', style: Theme.of(context).textTheme.bodyMedium)
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width >= 1500 ? 6 : MediaQuery.of(context).size.width >= 1100 ? 5 : MediaQuery.of(context).size.width >= 900 ? 4 : MediaQuery.of(context).size.width >= 700 ? 3 : 2,
                        childAspectRatio: 0.66,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: lib.watchLater.length,
                      itemBuilder: (ctx, i) {
                        final it = lib.watchLater[i];
                        return PosterTile(item: it, onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsPage(item: it)));
                        });
                      },
                    ),

                  const SizedBox(height: 24),
                  Text('History', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (lib.history.isEmpty)
                    Text('Nothing watched yet', style: Theme.of(context).textTheme.bodyMedium)
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width >= 1500 ? 6 : MediaQuery.of(context).size.width >= 1100 ? 5 : MediaQuery.of(context).size.width >= 900 ? 4 : MediaQuery.of(context).size.width >= 700 ? 3 : 2,
                        childAspectRatio: 0.66,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: lib.history.length,
                      itemBuilder: (ctx, i) {
                        final it = lib.history[i];
                        return PosterTile(item: it, onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsPage(item: it)));
                        });
                      },
                    ),
                ]),
              ),
            ),
          );
        },
      ),
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
  bool _resolvingPlay = false;
  bool _initialPlayLoading = false;
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
      _initialPlayLoading = true;
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
      setState(() {
        _loading = false;
        _initialPlayLoading = false;
      });
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
      _resolvingPlay = true;
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
      setState(() => _resolvingPlay = false);
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
    final isDesktop = MediaQuery.of(context).size.width > 1000;
    
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
              ),
            ),
          ),
          if (_resolvingPlay)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
              ),
            ),
          if (_initialPlayLoading)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Loading stream data...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please wait while we prepare your content',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          Container(
            width: 300,
            height: 450,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _getPosterUrl() != null
                  ? Image.network(_getPosterUrl()!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(Icons.movie, size: 64, color: Colors.white54),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 32),
          // Details
          Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
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
                const SizedBox(height: 24),
                
                // Title
                Text(
                  widget.item.title,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Metadata row
                _buildMetadataRow(),
                const SizedBox(height: 24),
                
                // Overview
                if (_details != null) ...[
                  Text(
                    'Overview',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _details!['overview'] ?? 'No overview available',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else if (_loadingDetails)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  const Text(
                    'Failed to load details',
                    style: TextStyle(color: Colors.white),
                  ),
                
                // Additional details
                if (_details != null) _buildAdditionalDetails(),
                
                const Spacer(),
                
                // Action buttons
                _buildActionButtons(),
                const SizedBox(height: 16),
                
                // Language controls (if available)
                if (_summary != null) _langControls(),
                
                // Error display
                if (_error != null) _buildErrorDisplay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
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
                _buildMetadataRow(),
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
                _buildActionButtons(),
                const SizedBox(height: 16),
                
                // Language controls (if available)
                if (_summary != null) _langControls(),
                
                // Error display
                if (_error != null) _buildErrorDisplay(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow() {
    return Row(
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
          widget.item.mediaType.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_details != null && _details!['runtime'] != null) ...[
          const SizedBox(width: 16),
          Text(
            '${_details!['runtime']} min',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
      ],
    );
  }

  Widget _buildAdditionalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Genres
        if (_details!['genres'] != null && (_details!['genres'] as List).isNotEmpty) ...[
          Text(
            'Genres',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (_details!['genres'] as List).map<Widget>((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  genre['name'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        
        // Cast
        if (_details!['credits'] != null && _details!['credits']['cast'] != null) ...[
                          Text(
            'Cast',
                            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
                              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: (_details!['credits']['cast'] as List).take(10).length,
              itemBuilder: (context, index) {
                final cast = (_details!['credits']['cast'] as List)[index];
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: cast['profile_path'] != null
                              ? DecorationImage(
                                  image: NetworkImage('https://image.tmdb.org/t/p/w200${cast['profile_path']}'),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: cast['profile_path'] == null ? Colors.grey[600] : null,
                        ),
                        child: cast['profile_path'] == null
                            ? const Icon(Icons.person, color: Colors.white, size: 30)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cast['name'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
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
    );
  }

  Widget _buildErrorDisplay() {
    return Container(
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
  Player? _player;
  VideoController? _videoController;
  bool _initError = false;
  bool _isLoading = true;
  bool _hlsCaptured = false;
  List<_ServerOption> _servers = [];
  _ServerOption? _currentServer;

  @override
  void initState() {
    super.initState();
    _prepareServersAndStart();
  }

  void _prepareServersAndStart() {
    _servers = [];
    if (widget.url.isNotEmpty) {
      _servers.add(_ServerOption(
        name: 'Server1',
        type: _ServerType.direct,
        directUrl: widget.url,
        referer: widget.referer,
      ));
    }
    if (widget.tmdbId != null) {
      _servers.add(_ServerOption(
        name: 'Server2',
        type: _ServerType.hlstr,
        tmdbOrImdbId: widget.tmdbId.toString(),
      ));
      _servers.add(_ServerOption(
        name: 'Server3',
        type: _ServerType.vidsrc,
      ));
    }
    if (_servers.isEmpty) {
      setState(() { _initError = true; _isLoading = false; });
      return;
    }
    _switchToServer(_servers.first);
  }

  Future<void> _switchToServer(_ServerOption server) async {
    _disposePlayers(keepWebView: false);
    setState(() {
      _currentServer = server;
      _isLoading = true;
      _initError = false;
      _hlsCaptured = false;
    });
    try {
      if (server.type == _ServerType.direct) {
        await _initializeDirect(server.directUrl!, referer: server.referer);
      } else if (server.type == _ServerType.hlstr) {
        await _playViaHlstr(server.tmdbOrImdbId!);
      } else if (server.type == _ServerType.vidsrc) {
        // Try new API flow; then HTML scrape fallback
        try {
          final vidsrc = VidsrcServerResolver();
          final res = await vidsrc.resolveViaApi(
            tmdbId: widget.tmdbId!,
            mediaType: widget.mediaType ?? 'movie',
          );
          await _setupPlayer(res);
        } catch (_) {
          final vidsrc = VidsrcServerResolver();
          final embedUrl = vidsrc.buildEmbedUrl(tmdbId: widget.tmdbId!, mediaType: widget.mediaType ?? 'movie');
          final res = await vidsrc.resolveViaHtml(embedUrl: embedUrl);
          await _setupPlayer(res);
        }
      }
    } catch (_) {
      _handleServerFailure(server);
    }
    // Record history for current title when playback is prepared
    try {
      if (widget.title.isNotEmpty && widget.tmdbId != null && widget.mediaType != null) {
        final item = TmdbItem(
          id: widget.tmdbId,
          title: widget.title,
          mediaType: widget.mediaType!,
          posterPath: (widget.details?['poster_path'] as String?),
        );
        LibraryService.instance.addToHistory(item);
      }
    } catch (_) {}
  }

  void _handleServerFailure(_ServerOption server) {
    // Remove failed server and try next
    _servers.removeWhere((s) => s.name == server.name);
    if (_servers.isNotEmpty) {
      _switchToServer(_servers.first);
    } else {
      setState(() { _initError = true; _isLoading = false; });
    }
  }

  Future<void> _initializeDirect(String url, {String? referer}) async {
    try {
      final res = await DirectServerResolver().resolve(url: url, referer: referer);
      await _setupPlayer(res);
    } catch (_) {
      setState(() { _initError = true; _isLoading = false; });
      if (_currentServer != null) _handleServerFailure(_currentServer!);
    }
  }

  static const String _userAgentFallback = 'Mozilla/5.0 (Linux; Android 12; Flutter) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  String? get _embedUrlFallback {
    if (widget.tmdbId == null) return null;
    final typePath = (widget.mediaType == 'tv') ? 'tv' : 'movie';
    return 'https://vidsrc.cc/v2/embed/$typePath/${widget.tmdbId}?autoPlay=true';
  }

  // Removed WebView-based vidsrc fallback

  Future<void> _playViaHlstr(String id) async {
    try {
      final res = await HlstrServerResolver().resolve(id: id);
      await _setupPlayer(res);
    } catch (_) {
      setState(() { _initError = true; _isLoading = false; });
      if (_currentServer != null) _handleServerFailure(_currentServer!);
    }
  }

  Future<void> _setupPlayer(ResolvedStream res) async {
    try {
      _player?.dispose();
      _player = Player();
      _videoController = VideoController(_player!);
      await _player!.open(
        Media(
          res.hlsUrl,
          httpHeaders: res.headers,
        ),
      );
      await _player!.setPlaylistMode(PlaylistMode.loop);
      await _player!.setVolume(100.0);
      if (!mounted) return;
      setState(() { _isLoading = false; });
    } catch (_) {
      setState(() { _initError = true; _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _disposePlayers(keepWebView: false);
    super.dispose();
  }

  void _disposePlayers({required bool keepWebView}) {
    _player?.dispose();
    _player = null;
    _videoController = null;
    // No WebView retained
  }

  Widget _buildServerButton(_ServerOption s, {bool compact = false}) {
    final bool isActive = (_currentServer?.name == s.name);
    final Widget label = Text(
      s.name,
      style: TextStyle(fontWeight: isActive ? FontWeight.w700 : FontWeight.w600),
    );
    if (isActive) {
      return ElevatedButton(
        onPressed: () => _switchToServer(s),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
        ),
        child: label,
      );
    }
    return OutlinedButton(
      onPressed: () => _switchToServer(s),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Theme.of(context).dividerColor, width: 1.5),
        padding: compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1000;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          if (_servers.isNotEmpty)
            PopupMenuButton<_ServerOption>(
              icon: const Icon(Icons.settings),
              onSelected: (server) => _switchToServer(server),
              itemBuilder: (context) => _servers.map((server) {
                final isActive = _currentServer?.name == server.name;
                return PopupMenuItem<_ServerOption>(
                  value: server,
                  child: Row(
                    children: [
                      if (isActive) const Icon(Icons.check, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(server.name),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
      body: Column(children: [
        // Video player
        Expanded(
          flex: isDesktop ? 3 : 2,
          child: Container(
            width: double.infinity,
            color: Colors.black,
          child: (_videoController == null || _isLoading)
              ? (_initError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.white54),
                          const SizedBox(height: 16),
                            const Text(
                              'Failed to load stream',
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try switching servers or check your connection',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                          if (_servers.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                              for (final s in _servers) _buildServerButton(s, compact: true),
                                ],
                              ),
                        ],
                      ),
                    )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text('Loading stream...', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ))
              : Video(controller: _videoController!),
        ),
        ),
        
        // Server controls
        if (_servers.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'SERVERS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        color: Colors.white,
                      ) ?? const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _servers) _buildServerButton(s),
                  ],
                ),
              ],
            ),
        ),
        
        // Movie details
        if (widget.details != null)
        Expanded(
            flex: isDesktop ? 2 : 1,
            child: Container(
              width: double.infinity,
            padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(top: BorderSide(color: Colors.grey[800]!)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((widget.details!['tagline'] ?? '').toString().isNotEmpty) ...[
                      Text(
                        (widget.details!['tagline'] ?? '').toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Overview',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                const SizedBox(height: 8),
                    Text(
                      (widget.details!['overview'] ?? '').toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ),
        ),
      ]),
    );
  }
}

enum _ServerType { direct, hlstr, vidsrc }

class _ServerOption {
  _ServerOption({required this.name, required this.type, this.directUrl, this.referer, this.tmdbOrImdbId});
  final String name;
  final _ServerType type;
  final String? directUrl;
  final String? referer;
  final String? tmdbOrImdbId;
}

// Removed VidsrcFallbackPage (WebView-based) as WebView is no longer used

