import 'package:flutter/cupertino.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
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
import '../theme/app_theme.dart';

// ── Design tokens (shared across app) ────────────────────────────────────────

const _live = Color(0xFF22C55E);
const _white = CupertinoColors.white;

TextStyle _font({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = _white,
  double spacing = 0,
  double height = 1.4,
}) =>
    GoogleFonts.spaceGrotesk(
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
      barrierDismissible: true,
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
      largeTitle: Text(
        (inChannels ? _selectedTitle : 'Live TV').toUpperCase(),
        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, letterSpacing: -1.0),
      ),
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
              child: const Icon(FluentIcons.chevron_left_24_regular),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inChannels) ...[
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _gridView = !_gridView),
              child: Icon(_gridView ? FluentIcons.list_24_regular : FluentIcons.grid_24_filled),
            ),
            if (_browseBy == BrowsingType.country)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _setDefaultCountry(_selectedItem as CountryEntry),
                child: Icon((_selectedItem as CountryEntry).code == _defaultCountryCode
                    ? FluentIcons.pin_24_filled
                    : FluentIcons.pin_24_regular),
              ),
          ] else
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                // Focus search or something
              },
              child: const Icon(FluentIcons.search_24_regular),
            ),
        ],
      ),
    );
  }

  // ── Browser View (no selection) ─────────────────────────────────────────────

  List<Widget> _buildBrowserView(CupertinoThemeData theme) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.brutalistDecoration(
          context: context,
          color: isDark ? AppTheme.darkSlate : AppTheme.creamBg,
          borderRadius: 4.0,
          shadowOffset: 4.0,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: AppTheme.brutalistDecoration(
                context: context,
                color: AppTheme.neonYellow,
                borderRadius: 4.0,
                shadowOffset: 2.0,
              ),
              child: const Icon(FluentIcons.video_clip_24_filled,
                  color: CupertinoColors.black, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LIVE CHANNELS',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: onSurface,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 3),
                  Text('Browse validated IPTV streams worldwide'.toUpperCase(),
                      style: _font(
                          size: 10,
                          color: onSurfaceVariant,
                          weight: FontWeight.w700)),
                ],
              ),
            ),
            const _LiveDot(large: true),
          ],
        ),
      ).animate().fadeIn(duration: 380.ms),
    );
  }

  Widget _buildModeSelector(CupertinoThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const modes = [
      (BrowsingType.country, 'Country'),
      (BrowsingType.category, 'Category'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: AppTheme.brutalistDecoration(
          context: context,
          color: isDark ? AppTheme.darkSlate : AppTheme.pureWhite,
          borderRadius: 4.0,
          shadowOffset: 2.0,
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
    final isDark = theme.brightness == Brightness.dark;

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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: AppTheme.brutalistDecoration(
                    context: context,
                    color: active ? AppTheme.neonYellow : (isDark ? AppTheme.darkSlate : AppTheme.pureWhite),
                    borderRadius: 4.0,
                    shadowOffset: active ? 2.5 : 1.5,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    cat.name.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: active ? CupertinoColors.black : onSurface,
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
                child: Container(
                  decoration: AppTheme.brutalistDecoration(
                    context: context,
                    color: isDark ? AppTheme.darkSlate : AppTheme.pureWhite,
                    borderRadius: 4.0,
                    shadowOffset: 2.0,
                  ),
                  child: CupertinoSearchTextField(
                    controller: _searchCtrl,
                    placeholder: 'SEARCH CHANNELS...',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    placeholderStyle: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: CupertinoColors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    onChanged: (val) => setState(() {}),
                    onSuffixTap: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Count pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: AppTheme.brutalistDecoration(
                  context: context,
                  color: AppTheme.neonYellow,
                  borderRadius: 4.0,
                  shadowOffset: 2.0,
                ),
                child: Text(
                  '${_filtered.length}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: CupertinoColors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Channel content
      if (_loadingChannels)
        const SliverFillRemaining(
          child: Center(child: IOSLoading(message: 'LOADING STREAMS…')),
        )
      else if (_filtered.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.tv_24_regular,
                    color: cs.onSurface.withValues(alpha: 0.15), size: 48),
                const SizedBox(height: 14),
                Text(
                  (_channels.isEmpty
                      ? 'No streams available'
                      : 'No channels found').toUpperCase(),
                  style: _font(
                      size: 14,
                      color: cs.onSurfaceVariant,
                      weight: FontWeight.w900),
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
    Widget leading;
    String label;

    switch (browseBy) {
      case BrowsingType.country:
        leading = Text((selectedItem as CountryEntry).flag,
            style: const TextStyle(fontSize: 20));
        label = (selectedItem as CountryEntry).name;
        break;
      case BrowsingType.category:
        leading = const Icon(FluentIcons.grid_24_filled,
            color: CupertinoColors.black, size: 18);
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
            label.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(fontSize: 20, color: onSurface, fontWeight: FontWeight.w900),
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
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(top: 6, bottom: 6, left: 6),
        decoration: AppTheme.brutalistDecoration(
          context: context,
          color: active ? AppTheme.neonYellow : (isDark ? AppTheme.darkSlate : AppTheme.pureWhite),
          borderRadius: 4.0,
          shadowOffset: active ? 1.5 : 0.0,
        ),
        child: Icon(icon,
            color: active ? CupertinoColors.black : onSurface, size: 16),
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
          horizontal: large ? 10 : 6, vertical: large ? 5 : 3),
      decoration: BoxDecoration(
        color: CupertinoColors.black,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppTheme.neonYellow, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 6 : 4,
            height: large ? 6 : 4,
            decoration:
                const BoxDecoration(color: _live, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: GoogleFonts.spaceGrotesk(
              color: CupertinoColors.white,
              fontSize: large ? 11 : 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
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
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: active
              ? AppTheme.brutalistDecoration(
                  context: context,
                  color: AppTheme.neonYellow,
                  borderRadius: 4.0,
                  shadowOffset: 0.0,
                )
              : const BoxDecoration(color: CupertinoColors.transparent),
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: active
                  ? CupertinoColors.black
                  : onSurface.withValues(alpha: 0.6),
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
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
    
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
          decoration: AppTheme.brutalistDecoration(
            context: context,
            color: AppTheme.neonYellow,
            borderRadius: 4.0,
            shadowOffset: 2.0,
          ),
          child: const Icon(FluentIcons.grid_24_filled, color: CupertinoColors.black, size: 24),
        );
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.brutalistDecoration(
          context: context,
          color: isDark ? AppTheme.darkSlate : AppTheme.creamBg,
          borderRadius: 4.0,
          shadowOffset: 3.5,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: Stack(
            children: [
              Positioned(
                right: -15,
                bottom: -15,
                child: Icon(
                  type == BrowsingType.country ? FluentIcons.globe_24_regular : FluentIcons.tag_24_filled,
                  size: 64,
                  color: onSurface.withValues(alpha: 0.04),
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
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: onSurface,
                        letterSpacing: -0.3,
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
    final onSurface = isDark ? CupertinoColors.white : CupertinoColors.black;
    final onSurfaceVariant = isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: AppTheme.brutalistDecoration(
          context: context,
          color: isDark ? AppTheme.darkSlate : AppTheme.pureWhite,
          borderRadius: 4.0,
          shadowOffset: 2.0,
        ),
        child: Row(
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 48,
                height: 48,
                decoration: AppTheme.brutalistDecoration(
                  context: context,
                  color: CupertinoColors.white,
                  borderRadius: 4.0,
                  shadowOffset: 0.0,
                ),
                child: channel.logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: channel.logoUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, _) =>
                            Container(color: CupertinoColors.white),
                        errorWidget: (_, _, _) => Icon(
                          FluentIcons.tv_24_filled,
                          color: CupertinoColors.black.withValues(alpha: 0.3),
                          size: 20,
                        ),
                      )
                    : Icon(FluentIcons.tv_24_filled,
                        color: CupertinoColors.black.withValues(alpha: 0.3),
                        size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: onSurface),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: _live, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (channel.group ?? 'LIVE').toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: onSurfaceVariant,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: AppTheme.brutalistDecoration(
                context: context,
                color: AppTheme.neonYellow,
                borderRadius: 4.0,
                shadowOffset: 0.0,
              ),
              child: const Icon(
                FluentIcons.play_circle_24_filled,
                color: CupertinoColors.black,
                size: 28,
              ),
            ),
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
    final onSurfaceVariant = isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.brutalistDecoration(
          context: context,
          color: isDark ? AppTheme.darkSlate : AppTheme.pureWhite,
          borderRadius: 4.0,
          shadowOffset: 2.0,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Logo centered
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              bottom: 44,
              child: Center(
                child: Hero(
                  tag: 'channel-logo-${channel.id}',
                  child: channel.logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: channel.logoUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => Icon(
                            FluentIcons.tv_24_filled,
                            color: onSurfaceVariant.withValues(alpha: 0.3),
                            size: 32,
                          ),
                        )
                      : Icon(FluentIcons.tv_24_filled,
                          color: onSurfaceVariant.withValues(alpha: 0.3),
                          size: 32),
                ),
              ),
            ),

            // Bottom name strip
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? CupertinoColors.black : AppTheme.neonYellow,
                  border: Border(
                    top: BorderSide(
                        color: isDark ? CupertinoColors.white : CupertinoColors.black,
                        width: 2.0),
                  ),
                ),
                child: Row(
                  children: [
                    const _LiveDot(),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        channel.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDark ? CupertinoColors.white : CupertinoColors.black,
                            letterSpacing: -0.3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      FluentIcons.play_circle_24_filled,
                      color: isDark ? AppTheme.neonYellow : CupertinoColors.black,
                      size: 14,
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



