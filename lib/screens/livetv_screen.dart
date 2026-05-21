import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/channel.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import 'live_player_screen.dart';
import '../widgets/ios_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';

// ── Design tokens (shared across app) ────────────────────────────────────────

const _live = Color(0xFF22C55E);
const _kRadius = 14.0;
const _kRadiusLg = 20.0;
const _white = CupertinoColors.white;

TextStyle _font({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = _white,
  double spacing = 0,
  double height = 1.4,
}) =>
    GoogleFonts.outfit(
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

  void _showToast(String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

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
      _showToast('${c.name} is now your default.');
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
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
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
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : const Color(0xFFF2F2F7),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildCupertinoAppBar(theme),
          if (_selectedItem == null)
            ..._buildBrowserView(theme)
          else
            ..._buildChannelView(theme),
        ],
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────────

  Widget _buildCupertinoAppBar(CupertinoThemeData theme) {
    final inChannels = _selectedItem != null;
    final isDark = theme.brightness == Brightness.dark;

    return CupertinoSliverNavigationBar(
      transitionBetweenRoutes: false,
      largeTitle: Text(inChannels ? _selectedTitle : 'Live TV'),
      backgroundColor: isDark ? const Color(0xCC000000) : const Color(0xCCF2F2F7),
      border: null,
      leading: inChannels
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() {
                _selectedItem = null;
                _channels = [];
                _filtered = [];
                _searchCtrl.clear();
                _subFilterCategory = null;
              }),
              child: const Icon(CupertinoIcons.chevron_back),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inChannels) ...[
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _gridView = !_gridView),
              child: Icon(_gridView ? CupertinoIcons.list_dash : CupertinoIcons.square_grid_2x2_fill),
            ),
            if (_browseBy == BrowsingType.country)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _setDefaultCountry(_selectedItem as CountryEntry),
                child: Icon((_selectedItem as CountryEntry).code == _defaultCountryCode
                    ? CupertinoIcons.pin_fill
                    : CupertinoIcons.pin),
              ),
          ] else
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                // Focus search or something
              },
              child: const Icon(CupertinoIcons.search),
            ),
        ],
      ),
    );
  }

  // ── Browser View (no selection) ─────────────────────────────────────────────

  List<Widget> _buildBrowserView(CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
    final onSurfaceVariant = isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2;
    final primary = theme.primaryColor;
    final surface = isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground;

    return [
      SliverToBoxAdapter(
        child: Column(
          children: [
            _buildHeroBanner(theme),
            const NativeAdWidget(size: NativeAdSize.small),
            BannerAdWidget(),
            _buildModeSelector(theme),
          ],
        ),
      ),
      if (_loadingInitial)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: IOSLoading(message: 'Loading…')),
        )
      else
        _buildPickerGrid(theme),
    ];
  }

  Widget _buildHeroBanner(CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
    final onSurfaceVariant = isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2;
    final primary = theme.primaryColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
              ],
            ),
            borderRadius: BorderRadius.circular(_kRadiusLg),
            border: Border.all(
                color: onSurface.withValues(alpha: 0.08), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(alpha: 0.1),
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
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(CupertinoIcons.play_rectangle_fill,
                  color: primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Channels',
                      style: GoogleFonts.outfit(
                          fontSize: 20, color: onSurface, letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text('Browse validated IPTV streams worldwide',
                      style: _font(
                          size: 12,
                          color: onSurfaceVariant,
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

  Widget _buildModeSelector(CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
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
          color: onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: onSurface.withValues(alpha: 0.07), width: 0.5),
        ),
        child: Row(
          children: modes
              .map((m) => _ModeTab(
                    label: m.$2,
                    active: _browseBy == m.$1,
                    onTap: () => setState(() => _browseBy = m.$1),
                    isDark: isDark,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPickerGrid(CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
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
                  isDark: isDark,
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

  List<Widget> _buildChannelView(CupertinoThemeData theme) {
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;
    final primary = cs.primary;

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
                        ? primary
                        : onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? primary
                          : onSurface.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    cat.name,
                    style: _font(
                      size: 12,
                      weight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? CupertinoColors.white : onSurfaceVariant,
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
              Expanded(
                child: CupertinoSearchTextField(
                  controller: _searchCtrl,
                  placeholder: 'Search channels...',
                  style: _font(size: 14, color: cs.onSurface, weight: FontWeight.w500),
                  placeholderStyle: _font(size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  onChanged: (val) => setState(() {}),
                  onSuffixTap: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
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
          child: Center(child: IOSLoading(message: 'Loading streams…')),
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
                      return const Center(child: IOSLoading(size: 28));
                    }
                    return _ChannelGridCard(
                      channel: _filtered[i],
                      onTap: () => _openPlayer(i),
                      isDark: cs.theme.brightness == Brightness.dark,
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
                    child: Center(child: IOSLoading(size: 28)),
                  );
                }
                return _ChannelTile(
                  channel: _filtered[i],
                  onTap: () => _openPlayer(i),
                  isDark: cs.theme.brightness == Brightness.dark,
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
    final theme = CupertinoTheme.of(context);
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
            color: theme.primaryColor, size: 18);
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
            style: GoogleFonts.outfit(fontSize: 20, color: onSurface),
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
  final bool active;

  const _AppBarAction({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
    final primary = theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(top: 6, bottom: 6, left: 6),
        decoration: BoxDecoration(
          color: active
              ? primary.withValues(alpha: 0.15)
              : onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.3)
                : onSurface.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Icon(icon,
            color: active ? primary : onSurface, size: 16),
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
            style: GoogleFonts.outfit(
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
  final bool isDark;

  const _ModeTab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: active ? theme.primaryColor : CupertinoColors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active
                  ? CupertinoColors.white
                  : onSurface.withValues(alpha: 0.45),
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
  final bool isDark;

  const _PickerCard({
    required this.item,
    required this.type,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
    final primary = theme.primaryColor;
    
    String label;
    Widget icon;

    switch (type) {
      case BrowsingType.country:
        label = (item as CountryEntry).name;
        icon = Text((item as CountryEntry).flag,
            style: const TextStyle(fontSize: 32));
        break;
      case BrowsingType.category:
        label = (item as CategoryEntry).name;
        icon = Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(CupertinoIcons.rectangle_grid_2x2_fill, color: primary, size: 24),
        );
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
              isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            ],
          ),
          border: Border.all(color: onSurface.withValues(alpha: 0.08), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kRadius),
          child: Stack(
            children: [
              Positioned(
                right: -15,
                bottom: -15,
                child: Icon(
                  type == BrowsingType.country ? CupertinoIcons.globe : CupertinoIcons.tag_fill,
                  size: 64,
                  color: onSurface.withValues(alpha: 0.03),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(height: 12),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Channel List Tile ─────────────────────────────────────────────────────────

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final bool isDark;

  const _ChannelTile(
      {required this.channel, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
    final onSurfaceVariant = isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2;
    final primary = theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E).withValues(alpha: 0.6) : const Color(0xFFE5E5EA).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(
              color: onSurface.withValues(alpha: 0.08), width: 0.5),
        ),
        child: Row(
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 48,
                height: 48,
                color: CupertinoColors.white,
                child: channel.logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: channel.logoUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, _) =>
                            Container(color: CupertinoColors.white.withValues(alpha: 0.1)),
                        errorWidget: (_, _, _) => Icon(
                          CupertinoIcons.tv_fill,
                          color: onSurfaceVariant.withValues(alpha: 0.3),
                          size: 20,
                        ),
                      )
                    : Icon(CupertinoIcons.tv_fill,
                        color: onSurfaceVariant.withValues(alpha: 0.3),
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
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onSurface),
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
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: onSurfaceVariant,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.play_circle_fill,
                color: primary, size: 28),
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
  final bool isDark;

  const _ChannelGridCard(
      {required this.channel, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
    final onSurfaceVariant = isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2;
    final primary = theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF2C2C2E).withValues(alpha: 0.9) : const Color(0xFFE5E5EA).withValues(alpha: 0.9),
              isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.6) : const Color(0xFFF2F2F7).withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(
              color: onSurface.withValues(alpha: 0.08), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Logo centered
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              bottom: 40,
              child: Center(
                child: Hero(
                  tag: 'channel-logo-${channel.id}',
                  child: channel.logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: channel.logoUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => Icon(
                            CupertinoIcons.tv_fill,
                            color: onSurfaceVariant.withValues(alpha: 0.2),
                            size: 32,
                          ),
                        )
                      : Icon(CupertinoIcons.tv_fill,
                          color: onSurfaceVariant.withValues(alpha: 0.2),
                          size: 32),
                ),
              ),
            ),

            // Bottom name strip
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? CupertinoColors.black.withValues(alpha: 0.8) : CupertinoColors.white.withValues(alpha: 0.8),
                      border: Border(
                        top: BorderSide(
                            color: onSurface.withValues(alpha: 0.06), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const _LiveDot(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            channel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                                letterSpacing: -0.3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(CupertinoIcons.play_circle_fill,
                            color: primary, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



