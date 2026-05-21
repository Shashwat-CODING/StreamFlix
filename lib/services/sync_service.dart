import 'dart:convert';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'watch_history.dart';
import 'bookmark_service.dart';
import 'collection_service.dart';
import 'settings_service.dart';
import 'music_history.dart';

class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSync;
  DateTime? get lastSync => _lastSync;

  Future<void> syncAll() async {
    if (!AuthService.instance.isAuthenticated) return;
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    debugPrint('🔄 [SYNC] Starting full data sync...');
    try {
      await Future.wait([
        syncWatchHistory(),
        syncBookmarks(),
        syncProgress(),
        syncCollections(),
        syncSettings(),
        syncMusicPlaylists(),
        syncMusicHistory(),
      ]);
      _lastSync = DateTime.now();
      debugPrint('✅ [SYNC] Full data sync completed.');
    } catch (e) {
      debugPrint('💥 [SYNC] Full sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> restoreAll() async {
    if (!AuthService.instance.isAuthenticated) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      final res = await ApiService.instance.rawGet(
        '/api/sync',
        headers: AuthService.instance.authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        if (data['history'] != null) await WatchHistory.restore(data['history']);
        if (data['bookmarks'] != null) await BookmarkService.restore(data['bookmarks']);
        if (data['music_history'] != null) await MusicHistory.restore(data['music_history']);
        
        CollectionService.instance.restore(
          data['playlists'] ?? [],
          data['collections'] ?? [],
          data['progress'] ?? {},
        );

        if (data['settings'] != null) {
          SettingsService.instance.restore(data['settings']);
        }
        
        _lastSync = DateTime.now();
        debugPrint('📥 [RESTORE] Data restored from server.');
      }
    } catch (e) {
      debugPrint('💥 [RESTORE] Error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncWatchHistory() async {
    final history = WatchHistory.history;
    await _postSync('/sync/history', {'history': history.map((e) => e.toJson()).toList()});
  }

  Future<void> syncBookmarks() async {
    final bookmarks = BookmarkService.bookmarks;
    await _postSync('/sync/bookmarks', {'bookmarks': bookmarks.map((e) => e.toJson()).toList()});
  }

  Future<void> syncProgress() async {
    final progress = CollectionService.instance.seriesProgress;
    await _postSync('/sync/progress', {'progress': progress.map((k, v) => MapEntry(k.toString(), v.toJson()))});
  }

  Future<void> syncCollections() async {
    final collections = CollectionService.instance.collections;
    await _postSync('/sync/collections', {'collections': collections.map((e) => e.toJson()).toList()});
  }

  Future<void> syncSettings() async {
    final settings = SettingsService.instance;
    await _postSync('/sync/settings', {
      'settings': {
        'theme_mode': settings.themeMode,
        'theme': settings.themeMode == 1 ? 'dark' : (settings.themeMode == 2 ? 'light' : 'system'),
        'accent_color': settings.accentColor?.value,
        'custom_font': settings.customFont,
        'auto_queue': settings.autoQueue,
        'autoplay': settings.autoQueue,
      }
    });
  }

  Future<void> syncMusicPlaylists() async {
    final playlists = CollectionService.instance.playlists;
    await _postSync('/sync/music/playlists', {'playlists': playlists.map((e) => e.toJson()).toList()});
  }

  Future<void> syncMusicHistory() async {
    final history = MusicHistory.history;
    await _postSync('/sync/music/history', {'history': history.map((e) => e.toJson()).toList()});
  }

  Future<void> _postSync(String endpoint, Map<String, dynamic> body) async {
    if (!AuthService.instance.isAuthenticated) return;
    
    try {
      final res = await ApiService.instance.rawPost(
        '/api$endpoint',
        headers: {
          ...AuthService.instance.authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        debugPrint('✅ [SYNC] $endpoint synced.');
        _lastSync = DateTime.now();
        notifyListeners();
      } else {
        debugPrint('❌ [SYNC] $endpoint failed: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('💥 [SYNC] $endpoint error: $e');
    }
  }
}
