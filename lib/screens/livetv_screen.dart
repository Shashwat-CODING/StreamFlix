import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/channel.dart';
import '../services/iptv_service.dart';
import 'live_player_screen.dart';
import '../widgets/m3_loading.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

enum BrowsingType { country, region, category, language }

class _LiveTvScreenState extends State<LiveTvScreen>
    with SingleTickerProviderStateMixin {
  final _service = IptvService();

  List<CountryEntry> _countries = [];
  List<RegionEntry> _regions = [];
  List<CategoryEntry> _categories = [];
  List<LanguageEntry> _languages = [];

  bool _loadingInitial = true;

  BrowsingType _browseBy = BrowsingType.country;
  dynamic _selectedItem; // CountryEntry, RegionEntry, etc.
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

  Future<void> _loadInitialData() async {
    setState(() => _loadingInitial = true);
    final results = await Future.wait([
      _service.fetchCountries(),
      _service.fetchRegions(),
      _service.fetchCategories(),
      _service.fetchLanguages(),
    ]);

    if (mounted) {
      setState(() {
        _countries = results[0] as List<CountryEntry>;
        _regions = results[1] as List<RegionEntry>;
        _categories = results[2] as List<CategoryEntry>;
        _languages = results[3] as List<LanguageEntry>;
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
      // Use different margin based on whether it's showing for the current item or in general
      // But for consistency with LiveTV navbar, use high bottom margin
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(c.flag, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Region Pinned',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${c.name} is now your default.',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            120,
          ), // Increased bottom margin to clear navbar
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
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
    if (_subFilterCategory == cat) {
      setState(() => _subFilterCategory = null);
    } else {
      setState(() => _subFilterCategory = cat);
    }

    setState(() {
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
      // If we have a category filter, we use search
      String q = _subFilterCategory!.name;
      String? country;
      if (_browseBy == BrowsingType.country && _selectedItem is CountryEntry) {
        country = _selectedItem.code;
      }
      response = await _service.searchChannels(
        q,
        category: _subFilterCategory!.id,
        country: country,
        page: page,
      );
    } else {
      switch (_browseBy) {
        case BrowsingType.country:
          response = await _service.fetchChannelsByCountry(
            (_selectedItem as CountryEntry).code,
            page: page,
          );
          break;
        case BrowsingType.region:
          response = await _service.fetchChannelsByRegion(
            (_selectedItem as RegionEntry).code,
            page: page,
          );
          break;
        case BrowsingType.category:
          response = await _service.searchChannels(
            (_selectedItem as CategoryEntry).name,
            category: (_selectedItem as CategoryEntry).id,
            page: page,
          );
          break;
        case BrowsingType.language:
          // Language isn't directly supported in country/region endpoints, use search
          response = await _service.searchChannels(
            (_selectedItem as LanguageEntry).name,
            page: page,
          );
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
      final response = await _service.searchChannels(
        _searchCtrl.text,
        page: _currentPage,
      );
      if (mounted) {
        setState(() {
          _filtered.addAll(response.results);
          _loadingMore = false;
          _hasMore =
              response.page < response.totalPages &&
              response.results.isNotEmpty;
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
      const Duration(milliseconds: 400),
      () => _performSearch(q),
    );
  }

  Future<void> _performSearch(String q) async {
    if (!mounted) return;
    setState(() {
      _loadingChannels = true;
      _isSearching = true;
      _currentPage = 1;
    });
    final response = await _service.searchChannels(q, page: _currentPage);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(cs),
          if (_selectedItem == null)
            ..._buildInitialPicker(cs)
          else
            ..._buildChannelContent(cs),
        ],
      ),
    );
  }

  Widget _buildAppBar(ColorScheme cs) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      snap: true,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: _selectedItem != null
          ? IconButton(
              icon: Icon(
                CupertinoIcons.chevron_back,
                size: 18,
                color: cs.onSurface,
              ),
              onPressed: () => setState(() {
                _selectedItem = null;
                _channels = [];
                _filtered = [];
                _searchCtrl.clear();
                _subFilterCategory = null;
              }),
            )
          : null,
      title: _selectedItem == null
          ? Row(
              children: [
                Image.asset('assets/ic_launcher.png', width: 28, height: 28),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'Live ',
                        style: TextStyle(color: cs.onSurface),
                      ),
                      TextSpan(
                        text: 'TV',
                        style: TextStyle(color: cs.primary),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                if (_browseBy == BrowsingType.country) ...[
                  Text(
                    (_selectedItem as CountryEntry).flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      (_selectedItem as CountryEntry).name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else if (_browseBy == BrowsingType.region) ...[
                  Icon(CupertinoIcons.globe, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      (_selectedItem as RegionEntry).name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else if (_browseBy == BrowsingType.category) ...[
                  Icon(
                    CupertinoIcons.rectangle_grid_2x2_fill,
                    color: cs.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      (_selectedItem as CategoryEntry).name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else if (_browseBy == BrowsingType.language) ...[
                  Icon(
                    CupertinoIcons.chat_bubble_fill,
                    color: cs.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      (_selectedItem as LanguageEntry).name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
      actions: [
        if (_selectedItem != null) ...[
          // View toggle
          IconButton(
            icon: Icon(
              _gridView
                  ? CupertinoIcons.list_dash
                  : CupertinoIcons.square_grid_2x2_fill,
              color: cs.onSurface,
              size: 20,
            ),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          // Pin as default (only for countries for now)
          if (_browseBy == BrowsingType.country)
            IconButton(
              icon: Icon(
                (_selectedItem as CountryEntry).code == _defaultCountryCode
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                color:
                    (_selectedItem as CountryEntry).code == _defaultCountryCode
                    ? cs.primary
                    : cs.onSurface,
                size: 20,
              ),
              tooltip: 'Set as Default',
              onPressed: () =>
                  _setDefaultCountry(_selectedItem as CountryEntry),
            ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }

  List<Widget> _buildInitialPicker(ColorScheme cs) {
    return [
      // Hero & Mode Selector
      SliverToBoxAdapter(
        child: Column(children: [_buildHero(cs), _buildModeSelector(cs)]),
      ),

      // Grid Items
      if (_loadingInitial)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: M3Loading(message: 'Loading browse data...')),
        )
      else
        _buildPickerGrid(cs),
    ];
  }

  Widget _buildHero(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.surfaceContainerHigh, cs.surfaceContainerHighest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.play_rectangle_fill, color: cs.primary, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Channels',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse validated IPTV streams worldwide',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF22C55E).withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'LIVE',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF22C55E),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildModeSelector(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            _uniqueModeTab('Country', BrowsingType.country, cs),
            _uniqueModeTab('Region', BrowsingType.region, cs),
            _uniqueModeTab('Category', BrowsingType.category, cs),
            _uniqueModeTab('Language', BrowsingType.language, cs),
          ],
        ),
      ),
    );
  }

  Widget _uniqueModeTab(String label, BrowsingType type, ColorScheme cs) {
    final active = _browseBy == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _browseBy = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: active ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active
                  ? cs.onPrimary
                  : cs.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerGrid(ColorScheme cs) {
    int count = 0;
    switch (_browseBy) {
      case BrowsingType.country:
        count = _countries.length;
        break;
      case BrowsingType.region:
        count = _regions.length;
        break;
      case BrowsingType.category:
        count = _categories.length;
        break;
      case BrowsingType.language:
        count = _languages.length;
        break;
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate((_, i) {
              final item = _getItemAt(i);
              return _PickerCard(
                item: item,
                type: _browseBy,
                onTap: () => _selectItem(item, _browseBy),
                cs: cs,
              ).animate(delay: (i % 30 * 5).ms).fadeIn(duration: 150.ms);
            }, childCount: count),
          );
        },
      ),
    );
  }

  dynamic _getItemAt(int i) {
    switch (_browseBy) {
      case BrowsingType.country:
        return _countries[i];
      case BrowsingType.region:
        return _regions[i];
      case BrowsingType.category:
        return _categories[i];
      case BrowsingType.language:
        return _languages[i];
    }
  }

  List<Widget> _buildChannelContent(ColorScheme cs) {
    return [
      // Category Filter Chips (Horizontal)
      SliverToBoxAdapter(
        child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length.clamp(0, 15),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = _categories[i];
              final active = _subFilterCategory?.id == cat.id;
              return GestureDetector(
                onTap: () => _toggleCategoryFilter(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: active
                        ? cs.primary
                        : cs.surfaceContainerHigh.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? cs.primary
                          : cs.outlineVariant.withOpacity(0.1),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    cat.name,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      color: active
                          ? cs.onPrimary
                          : cs.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      // Stats bar
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${_channels.length} ${_isSearching ? 'found' : 'channels'}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_hasMore)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'More available ↓',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      // Search bar
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(CupertinoIcons.search, color: cs.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search channels…',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withOpacity(0.55),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      filled: false,
                    ),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchCtrl.clear(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
      // Channel list / grid
      if (_loadingChannels)
        const SliverFillRemaining(
          child: Center(child: M3Loading(message: 'Loading streams...')),
        )
      else if (_filtered.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.play_rectangle_fill,
                  color: cs.outlineVariant,
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text(
                  _channels.isEmpty
                      ? 'No streams available'
                      : 'No channels found',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        )
      else if (_gridView)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.crossAxisExtent >= 1200
                  ? 6
                  : constraints.crossAxisExtent >= 900
                  ? 5
                  : constraints.crossAxisExtent >= 600
                  ? 4
                  : 3;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.15,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((_, i) {
                  if (i == _filtered.length) {
                    return const Center(child: M3Loading(size: 28));
                  }
                  final ch = _filtered[i];
                  return _ChannelGridCard(
                    channel: ch,
                    onTap: () => _openPlayer(i),
                    cs: cs,
                  ).animate(delay: (i % 9 * 20).ms).fadeIn(duration: 200.ms);
                }, childCount: _filtered.length + (_hasMore ? 1 : 0)),
              );
            },
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              if (i == _filtered.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: M3Loading(size: 28),
                  ),
                );
              }
              final ch = _filtered[i];
              return _ChannelTile(
                channel: ch,
                onTap: () => _openPlayer(i),
                cs: cs,
              ).animate(delay: (i * 5).ms).fadeIn(duration: 160.ms);
            }, childCount: _filtered.length + (_hasMore ? 1 : 0)),
          ),
        ),
    ];
  }
}

// ── Picker Card ──────────────────────────────────────────────────────────────

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
    String label = '';
    Widget icon = const SizedBox();

    if (type == BrowsingType.country) {
      label = (item as CountryEntry).name;
      icon = Text(
        (item as CountryEntry).flag,
        style: const TextStyle(fontSize: 26),
      );
    } else if (type == BrowsingType.region) {
      label = (item as RegionEntry).name;
      icon = Icon(CupertinoIcons.globe, color: cs.primary, size: 28);
    } else if (type == BrowsingType.category) {
      label = (item as CategoryEntry).name;
      icon = Icon(
        CupertinoIcons.rectangle_grid_2x2_fill,
        color: cs.primary,
        size: 28,
      );
    } else if (type == BrowsingType.language) {
      label = (item as LanguageEntry).name;
      icon = Icon(CupertinoIcons.chat_bubble_fill, color: cs.primary, size: 28);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
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

  const _ChannelTile({
    required this.channel,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
        ),
        child: Row(
          children: [
            // Logo
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: channel.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: channel.logoUrl!,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => Icon(
                        CupertinoIcons.tv_fill,
                        color: cs.onSurfaceVariant.withOpacity(0.4),
                        size: 22,
                      ),
                    )
                  : Icon(
                      CupertinoIcons.tv_fill,
                      color: cs.onSurfaceVariant.withOpacity(0.4),
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        channel.group ?? 'Live',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.play_circle_fill, color: cs.primary, size: 30),
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

  const _ChannelGridCard({
    required this.channel,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 30),
                child: Center(
                  child: channel.logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: channel.logoUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Icon(
                            CupertinoIcons.tv_fill,
                            color: cs.onSurfaceVariant.withOpacity(0.3),
                            size: 26,
                          ),
                        )
                      : Icon(
                          CupertinoIcons.tv_fill,
                          color: cs.onSurfaceVariant.withOpacity(0.3),
                          size: 26,
                        ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(0.85),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.play_circle_fill,
                      color: cs.primary,
                      size: 18,
                    ),
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
