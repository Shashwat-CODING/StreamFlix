import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/channel.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import 'live_player_screen.dart';
import '../widgets/m3_loading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';

// ── Design tokens (shared across app) ────────────────────────────────────────

const _accent = Color(0xFFE50914);
const _live = Color(0xFF22C55E);
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

// ── Live TV Screen ────────────────────────────────────────────────────────────

enum BrowsingType { country, category }

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final _api = ApiService.instance;

  List<CountryEntry> _countries = [];
  List<RegionEntry> _regions = [];
  List<CategoryEntry> _categories = [];
  List<LanguageEntry> _languages = [];

  bool _loadingInitial = true;
  BrowsingType _browseBy = BrowsingType.country;
  dynamic _selectedItem;
  CategoryEntry? _subFilterCategory;

  List<Channel> _channels = [];
  List<Channel> _filtered = [];
  bool _loadingChannels = false;

  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  Timer? _debounce;
  bool _isSearching = false;
  bool _gridView = true;
  String? _defaultCountryCode;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchCtrl.addListener(_applyFilter);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loadingInitial = true);
    final results = await Future.wait([
      _api.fetchCountries(),
      _api.fetchCategories(),
    ]);
    if (mounted) {
      setState(() {
        _countries = results[0] as List<CountryEntry>;
        _categories = results[1] as List<CategoryEntry>;
        _loadingInitial = false;
      });
      await _loadDefaultCountry();
    }
  }

  Future<void> _loadDefaultCountry() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('default_country_code');
    if (mounted) setState(() => _defaultCountryCode = code);
    if (code != null && _countries.isNotEmpty) {
      final country = _countries.firstWhere(
        (c) => c.code == code,
        orElse: () => _countries.first,
      );
      _selectItem(country, BrowsingType.country);
    }
  }

  Future<void> _setDefaultCountry(CountryEntry c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_country_code', c.code);
    if (mounted) {
      setState(() => _defaultCountryCode = c.code);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(c.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Region Pinned',
                        style: _font(size: 13, weight: FontWeight.w700)),
                    Text('${c.name} is now your default.',
                        style: _font(size: 12, color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_kRadius)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _selectItem(dynamic item, BrowsingType type) async {
    setState(() {
      _selectedItem = item;
      _browseBy = type;
      _loadingChannels = true;
      _channels = [];
      _filtered = [];
      _searchCtrl.clear();
      _currentPage = 1;
      _hasMore = true;
      _subFilterCategory = null;
    });
    await _fetchChannels();
  }

  Future<void> _toggleCategoryFilter(CategoryEntry cat) async {
    setState(() {
      _subFilterCategory = _subFilterCategory == cat ? null : cat;
      _loadingChannels = true;
      _channels = [];
      _filtered = [];
      _currentPage = 1;
      _hasMore = true;
    });
    await _fetchChannels();
  }

  Future<void> _fetchChannels() async {
    IptvResponse response;
    final page = _currentPage;

    if (_subFilterCategory != null) {
      String? country;
      if (_browseBy == BrowsingType.country && _selectedItem is CountryEntry) {
        country = _selectedItem.code;
      }
      response = await _api.searchChannels(
        _subFilterCategory!.name,
        category: _subFilterCategory!.id,
        country: country,
        page: page,
      );
    } else {
      switch (_browseBy) {
        case BrowsingType.country:
          response = await _api.fetchChannelsByCountry(
              (_selectedItem as CountryEntry).code,
              page: page);
          break;
        case BrowsingType.category:
          response = await _api.searchChannels(
              (_selectedItem as CategoryEntry).name,
              category: (_selectedItem as CategoryEntry).id,
              page: page);
          break;
      }
    }

    if (mounted) {
      setState(() {
        if (page == 1) {
          _channels = response.results;
          _filtered = response.results;
        } else {
          _channels.addAll(response.results);
          _filtered = _channels;
        }
        _loadingChannels = false;
        _loadingMore = false;
        _hasMore =
            response.page < response.totalPages && response.results.isNotEmpty;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _currentPage++;
    if (_isSearching) {
      final response = await _api.searchChannels(_searchCtrl.text,
          page: _currentPage);
      if (mounted) {
        setState(() {
          _filtered.addAll(response.results);
          _loadingMore = false;
          _hasMore =
              response.page < response.totalPages && response.results.isNotEmpty;
        });
      }
    } else {
      await _fetchChannels();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _applyFilter() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _filtered = _channels;
        _isSearching = false;
        _currentPage = (_channels.length / 20).ceil();
        _hasMore = true;
      });
      return;
    }
    _debounce = Timer(
        const Duration(milliseconds: 400), () => _performSearch(q));
  }

  Future<void> _performSearch(String q) async {
    if (!mounted) return;
    setState(() {
      _loadingChannels = true;
      _isSearching = true;
      _currentPage = 1;
    });
    final response = await _api.searchChannels(q, page: _currentPage);
    if (mounted) {
      setState(() {
        _filtered = response.results;
        _loadingChannels = false;
        _hasMore = response.page < response.totalPages;
      });
    }
  }

  void _openPlayer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LivePlayerScreen(
          channel: _filtered[index],
          playlist: _filtered,
          initialIndex: index,
        ),
      ),
    );
  }

  String get _selectedTitle {
    if (_selectedItem == null) return '';
    switch (_browseBy) {
      case BrowsingType.country:
        return (_selectedItem as CountryEntry).name;
      case BrowsingType.category:
        return (_selectedItem as CategoryEntry).name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator.adaptive(
        onRefresh: _loadInitialData,
        color: cs.primary,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()), // Always permit scroll for RefreshIndicator
              slivers: [
                _buildAppBar(cs),
                if (_selectedItem == null)
                  ..._buildBrowserView(cs)
                else
                  ..._buildChannelView(cs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar(ColorScheme cs) {
    final inChannels = _selectedItem != null;

    return SliverAppBar(
      floating: true,
      pinned: true,
      snap: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: inChannels ? 48 : 0,
      leading: inChannels
          ? Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedItem = null;
                  _channels = [];
                  _filtered = [];
                  _searchCtrl.clear();
                  _subFilterCategory = null;
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.08), width: 0.5),
                  ),
                  child: Icon(CupertinoIcons.chevron_back,
                      color: cs.onSurface, size: 16),
                ),
              ),
            )
          : const SizedBox.shrink(),
      title: Row(
        children: [
          if (!inChannels) ...[
            Image.asset(
              'assets/logo.png',
              width: 24,
              height: 24,
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(width: 8),
            Text(
              'Drishya',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(width: 8),
            const _LiveDot(),
          ] else
            _AppBarTitle(
              browseBy: _browseBy,
              selectedItem: _selectedItem,
              onSurface: cs.onSurface,
            ),
        ],
      ),
      actions: [
        if (inChannels) ...[
          _AppBarAction(
            icon: _gridView
                ? CupertinoIcons.list_dash
                : CupertinoIcons.square_grid_2x2_fill,
            onTap: () => setState(() => _gridView = !_gridView),
            cs: cs,
          ),
          if (_browseBy == BrowsingType.country)
            _AppBarAction(
              icon: (_selectedItem as CountryEntry).code == _defaultCountryCode
                  ? CupertinoIcons.pin_fill
                  : CupertinoIcons.pin,
              onTap: () => _setDefaultCountry(_selectedItem as CountryEntry),
              cs: cs,
              active: (_selectedItem as CountryEntry).code ==
                  _defaultCountryCode,
            ),
        ] else
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () {
                // Since Live TV has its search inside the channel list, 
                // the main search button can trigger a focus on a global search if added later.
              },
              icon: Icon(CupertinoIcons.search, color: cs.onSurface, size: 24),
            ).animate().fadeIn(delay: 200.ms),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Browser View (no selection) ─────────────────────────────────────────────

  List<Widget> _buildBrowserView(ColorScheme cs) {
    return [
      SliverToBoxAdapter(
        child: Column(
          children: [
            _buildHeroBanner(cs),
            const NativeAdWidget(size: NativeAdSize.small),
            BannerAdWidget(),
            _buildModeSelector(cs),
          ],
        ),
      ),
      if (_loadingInitial)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: M3Loading(message: 'Loading…')),
        )
      else
        _buildPickerGrid(cs),
    ];
  }

  Widget _buildHeroBanner(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surfaceContainerHigh.withValues(alpha: 0.8),
                cs.surfaceContainer.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(_kRadiusLg),
            border: Border.all(
                color: cs.onSurface.withValues(alpha: 0.08), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(CupertinoIcons.play_rectangle_fill,
                  color: _accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Channels',
                      style: GoogleFonts.dmSerifDisplay(
                          fontSize: 20, color: cs.onSurface, letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text('Browse validated IPTV streams worldwide',
                      style: _font(
                          size: 12,
                          color: cs.onSurfaceVariant,
                          weight: FontWeight.w500)),
                ],
              ),
            ),
            _LiveDot(large: true),
          ],
        ),
      ).animate().fadeIn(duration: 380.ms),
    );
  }

  Widget _buildModeSelector(ColorScheme cs) {
    const modes = [
      (BrowsingType.country, 'Country'),
      (BrowsingType.category, 'Category'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: cs.onSurface.withValues(alpha: 0.07), width: 0.5),
        ),
        child: Row(
          children: modes
              .map((m) => _ModeTab(
                    label: m.$2,
                    active: _browseBy == m.$1,
                    onTap: () => setState(() => _browseBy = m.$1),
                    cs: cs,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPickerGrid(ColorScheme cs) {
    final count = switch (_browseBy) {
      BrowsingType.country => _countries.length,
      BrowsingType.category => _categories.length,
    };

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final maxExtent = constraints.crossAxisExtent >= 1200
              ? 140.0
              : constraints.crossAxisExtent >= 600
                  ? 160.0
                  : 180.0;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxExtent,
              childAspectRatio: 1.05,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final item = _getItemAt(i);
                return _PickerCard(
                  item: item,
                  type: _browseBy,
                  onTap: () => _selectItem(item, _browseBy),
                  cs: cs,
                ).animate(delay: (i % 30 * 5).ms).fadeIn(duration: 150.ms);
              },
              childCount: count,
            ),
          );
        },
      ),
    );
  }

  dynamic _getItemAt(int i) => switch (_browseBy) {
        BrowsingType.country => _countries[i],
        BrowsingType.category => _categories[i],
      };

  // ── Channel View ────────────────────────────────────────────────────────────

  List<Widget> _buildChannelView(ColorScheme cs) {
    return [
      // Category filter chips
      SliverToBoxAdapter(
        child: SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length.clamp(0, 15),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final active = _subFilterCategory?.id == cat.id;
              return GestureDetector(
                onTap: () => _toggleCategoryFilter(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: active
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    cat.name,
                    style: _font(
                      size: 12,
                      weight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),

      // Search + stats row
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              // Search field
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.08), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(CupertinoIcons.search,
                          color: cs.onSurfaceVariant, size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: _font(
                              size: 14,
                              color: cs.onSurface,
                              weight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search channels…',
                            hintStyle: _font(
                                size: 14,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () => _searchCtrl.clear(),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(CupertinoIcons.xmark_circle_fill,
                                size: 16,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.5)),
                          ),
                        )
                      else
                        const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Count pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.08), width: 0.5),
                ),
                child: Text(
                  '${_filtered.length}',
                  style: _font(
                      size: 13,
                      weight: FontWeight.w700,
                      color: cs.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),

      // Channel content
      if (_loadingChannels)
        const SliverFillRemaining(
          child: Center(child: M3Loading(message: 'Loading streams…')),
        )
      else if (_filtered.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.tv,
                    color: cs.onSurface.withValues(alpha: 0.15), size: 48),
                const SizedBox(height: 14),
                Text(
                  _channels.isEmpty
                      ? 'No streams available'
                      : 'No channels found',
                  style: _font(
                      size: 15,
                      color: cs.onSurfaceVariant,
                      weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        )
      else if (_gridView)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.crossAxisExtent >= 1200
                  ? 6
                  : constraints.crossAxisExtent >= 900
                      ? 5
                      : constraints.crossAxisExtent >= 600
                          ? 4
                          : 3;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  childAspectRatio: 1.15,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    if (i == _filtered.length) {
                      return const Center(child: M3Loading(size: 28));
                    }
                    return _ChannelGridCard(
                      channel: _filtered[i],
                      onTap: () => _openPlayer(i),
                      cs: cs,
                    )
                        .animate(delay: (i % 9 * 18).ms)
                        .fadeIn(duration: 200.ms);
                  },
                  childCount: _filtered.length + (_hasMore ? 1 : 0),
                ),
              );
            },
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                if (i == _filtered.length) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: M3Loading(size: 28)),
                  );
                }
                return _ChannelTile(
                  channel: _filtered[i],
                  onTap: () => _openPlayer(i),
                  cs: cs,
                ).animate(delay: (i * 4).ms).fadeIn(duration: 150.ms);
              },
              childCount: _filtered.length + (_hasMore ? 1 : 0),
            ),
          ),
        ),
    ];
  }
}

// ── App Bar Title ─────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  final BrowsingType browseBy;
  final dynamic selectedItem;
  final Color onSurface;

  const _AppBarTitle({
    required this.browseBy,
    required this.selectedItem,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    Widget leading;
    String label;

    switch (browseBy) {
      case BrowsingType.country:
        leading = Text((selectedItem as CountryEntry).flag,
            style: const TextStyle(fontSize: 20));
        label = (selectedItem as CountryEntry).name;
        break;
      case BrowsingType.category:
        leading = Icon(CupertinoIcons.rectangle_grid_2x2_fill,
            color: _accent, size: 18);
        label = (selectedItem as CategoryEntry).name;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: onSurface),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── App Bar Action ────────────────────────────────────────────────────────────

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool active;

  const _AppBarAction({
    required this.icon,
    required this.onTap,
    required this.cs,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(top: 6, bottom: 6, left: 6),
        decoration: BoxDecoration(
          color: active
              ? _accent.withValues(alpha: 0.15)
              : cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? _accent.withValues(alpha: 0.3)
                : cs.onSurface.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Icon(icon,
            color: active ? _accent : cs.onSurface, size: 16),
      ),
    );
  }
}

// ── Live Dot ──────────────────────────────────────────────────────────────────

class _LiveDot extends StatelessWidget {
  final bool large;
  const _LiveDot({this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 7, vertical: large ? 5 : 3),
      decoration: BoxDecoration(
        color: _live.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _live.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 6 : 5,
            height: large ? 6 : 5,
            decoration:
                const BoxDecoration(color: _live, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: GoogleFonts.dmSans(
              color: _live,
              fontSize: large ? 11 : 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mode Tab ──────────────────────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ModeTab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: active ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active
                  ? Colors.white
                  : cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Picker Card ───────────────────────────────────────────────────────────────

class _PickerCard extends StatelessWidget {
  final dynamic item;
  final BrowsingType type;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _PickerCard({
    required this.item,
    required this.type,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    Widget icon;

    switch (type) {
      case BrowsingType.country:
        label = (item as CountryEntry).name;
        icon = Text((item as CountryEntry).flag,
            style: const TextStyle(fontSize: 26));
        break;
      case BrowsingType.category:
        label = (item as CategoryEntry).name;
        icon = Icon(CupertinoIcons.rectangle_grid_2x2_fill,
            color: cs.primary, size: 26);
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(
              color: cs.onSurface.withValues(alpha: 0.07), width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _font(
                  size: 12,
                  weight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Channel List Tile ─────────────────────────────────────────────────────────

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ChannelTile(
      {required this.channel, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(
              color: cs.onSurface.withValues(alpha: 0.08), width: 0.5),
        ),
        child: Row(
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 48,
                height: 48,
                color: Colors.white,
                child: channel.logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: channel.logoUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, _) =>
                            Container(color: Colors.white10),
                        errorWidget: (_, _, _) => Icon(
                          CupertinoIcons.tv_fill,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                          size: 20,
                        ),
                      )
                    : Icon(CupertinoIcons.tv_fill,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _font(
                        size: 14,
                        weight: FontWeight.w600,
                        color: cs.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: _live, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        channel.group ?? 'Live',
                        style: _font(
                            size: 12,
                            color: cs.onSurfaceVariant,
                            weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.play_circle_fill,
                color: cs.primary, size: 28),
          ],
        ),
      ),
    );
  }
}

// ── Channel Grid Card ─────────────────────────────────────────────────────────

class _ChannelGridCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ChannelGridCard(
      {required this.channel, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(
              color: cs.onSurface.withValues(alpha: 0.08), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Logo centered
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              bottom: 34,
              child: Center(
                child: channel.logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: channel.logoUrl!,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => Icon(
                          CupertinoIcons.tv_fill,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                          size: 24,
                        ),
                      )
                    : Icon(CupertinoIcons.tv_fill,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                        size: 24),
              ),
            ),

            // Bottom name strip
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.9),
                  border: Border(
                    top: BorderSide(
                        color: cs.onSurface.withValues(alpha: 0.06), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          color: _live, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _font(
                            size: 11,
                            weight: FontWeight.w600,
                            color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.play_circle_fill,
                        color: cs.primary, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
