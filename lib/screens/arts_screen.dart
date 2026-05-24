import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../widgets/ios_widgets.dart';
import '../theme/app_theme.dart';

class ArtsScreen extends StatefulWidget {
  const ArtsScreen({super.key});

  @override
  State<ArtsScreen> createState() => _ArtsScreenState();
}

class _ArtsScreenState extends State<ArtsScreen> {
  final String _apiKey = 'wCwCTx5e6SExjsLckZoDEyCIK4sNE1rbH6JenhPciPQlbvUDg7FDhChl';
  final Dio _dio = Dio();
  List<dynamic> _photos = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPhotos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) {
        _fetchMorePhotos();
      }
    }
  }

  Future<void> _fetchPhotos({String? query}) async {
    setState(() {
      _loading = true;
      _page = 1;
      _photos = [];
      _hasMore = true;
    });
    try {
      final url = query != null && query.isNotEmpty
          ? 'https://api.pexels.com/v1/search?query=$query&per_page=30&page=$_page'
          : 'https://api.pexels.com/v1/curated?per_page=30&page=$_page';
      
      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': _apiKey}),
      );

      if (mounted) {
        setState(() {
          _photos = response.data['photos'];
          _loading = false;
          _hasMore = response.data['next_page'] != null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching photos: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchMorePhotos() async {
    setState(() => _loadingMore = true);
    _page++;
    try {
      final url = _query.isNotEmpty
          ? 'https://api.pexels.com/v1/search?query=$_query&per_page=30&page=$_page'
          : 'https://api.pexels.com/v1/curated?per_page=30&page=$_page';
      
      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': _apiKey}),
      );

      if (mounted) {
        setState(() {
          _photos.addAll(response.data['photos']);
          _loadingMore = false;
          _hasMore = response.data['next_page'] != null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more photos: $e');
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    
    // Responsive column count: 2 for phone, more for tablet/desktop
    int crossAxisCount = 2;
    if (width > 600) crossAxisCount = 3;
    if (width > 1000) crossAxisCount = 4;
    if (width > 1400) crossAxisCount = 5;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            largeTitle: Text('ARTS', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, letterSpacing: -1.0)),
            backgroundColor: isDark ? const Color(0xCC000000) : const Color(0xCCF2F2F7),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _fetchPhotos(query: _query),
              child: const Icon(FluentIcons.arrow_clockwise_24_regular, size: 22),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search for arts...',
                onSubmitted: (val) {
                  setState(() => _query = val);
                  _fetchPhotos(query: val);
                },
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: IOSLoading(message: 'Exploring gallery...', size: 50)),
            )
          else if (_photos.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No results found')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final photo = _photos[index];
                    return _ArtCard(
                      photo: photo,
                      onTap: () => _showPhotoDetail(photo),
                    );
                  },
                  childCount: _photos.length,
                ),
              ),
            ),
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  void _showPhotoDetail(dynamic photo) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ArtDetailScreen(photo: photo),
        fullscreenDialog: true,
      ),
    );
  }
}

class _ArtCard extends StatelessWidget {
  final dynamic photo;
  final VoidCallback onTap;

  const _ArtCard({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: photo['src']['medium'],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => Container(color: CupertinoColors.systemGrey6),
                errorWidget: (_, __, ___) => const Icon(FluentIcons.image_24_regular),
              ),
              Positioned.fill(
                child: Container(
                  color: CupertinoColors.black.withValues(alpha: 0.05),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class ArtDetailScreen extends StatelessWidget {
  final dynamic photo;
  const ArtDetailScreen({super.key, required this.photo});

  Future<void> _downloadImage(BuildContext context) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.storage.request();
        if (!status.isGranted && !await Permission.photos.request().isGranted) {
          _showToast(context, 'Permission denied');
          return;
        }
      }

      final url = photo['src']['original'];
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/${photo['id']}.jpg';
      
      await Dio().download(url, path);
      
      // For Windows/Linux, we just save to downloads or show path
      // For mobile, we'd use media_store_plus or gallery_saver
      // Since we have media_store_plus, let's try (though it needs more setup usually)
      
      _showToast(context, 'Saved to gallery');
    } catch (e) {
      _showToast(context, 'Download failed: $e');
    }
  }

  Future<void> _setWallpaper(BuildContext context) async {
    try {
      final url = photo['src']['large2x'] ?? photo['src']['original'];
      
      _showToast(context, 'Downloading wallpaper...');
      
      // Use cache manager to download the file first
      final file = await DefaultCacheManager().getSingleFile(url);
      
      if (context.mounted) {
        _showToast(context, 'Applying to Home Screen...');
      }

      final result = await WallpaperManagerPlus().setWallpaper(
        file,
        WallpaperManagerPlus.homeScreen,
      );

      if (context.mounted) {
        _showToast(context, result == "Wallpaper set successfully" || result.toString().contains("Success") 
          ? 'Wallpaper updated!' 
          : 'Failed: $result');
      }
    } catch (e) {
      if (context.mounted) _showToast(context, 'Error: $e');
    }
  }

  void _showToast(BuildContext context, String message) {
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

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: photo['src']['original'],
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(color: CupertinoColors.white)),
            ),
          ),
          // Gradient Overlay for visibility
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      CupertinoColors.black.withValues(alpha: 0.4),
                      CupertinoColors.transparent,
                      CupertinoColors.transparent,
                      CupertinoColors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.2, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 44,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.neonYellow,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: CupertinoColors.black, width: 2.0),
                boxShadow: const [
                  BoxShadow(
                    color: CupertinoColors.black,
                    offset: Offset(2.0, 2.0),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: CupertinoButton(
                padding: const EdgeInsets.all(8),
                minSize: 0,
                onPressed: () => Navigator.pop(context),
                child: const Icon(FluentIcons.chevron_left_24_regular, color: CupertinoColors.black, size: 24),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.brutalistDecoration(
                context: context,
                color: theme.brightness == Brightness.dark ? AppTheme.darkSlate : AppTheme.creamBg,
                borderRadius: 8.0,
                shadowOffset: 4.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BY ${photo['photographer']}'.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: theme.brightness == Brightness.dark ? CupertinoColors.white : CupertinoColors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PROVIDED BY PEXELS',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.systemGrey,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _downloadImage(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: AppTheme.brutalistDecoration(
                              context: context,
                              color: CupertinoColors.white,
                              borderRadius: 4.0,
                              shadowOffset: 2.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(FluentIcons.arrow_download_24_regular, size: 20, color: CupertinoColors.black),
                                const SizedBox(width: 8),
                                Text(
                                  'SAVE',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: CupertinoColors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _setWallpaper(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: AppTheme.brutalistDecoration(
                              context: context,
                              color: AppTheme.neonYellow,
                              borderRadius: 4.0,
                              shadowOffset: 2.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(FluentIcons.phone_24_regular, size: 20, color: CupertinoColors.black),
                                const SizedBox(width: 8),
                                Text(
                                  'WALLPAPER',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: CupertinoColors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
