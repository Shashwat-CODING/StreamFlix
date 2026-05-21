import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

import '../services/collection_service.dart';
import '../services/sync_service.dart';

class WatchHistory {
  static List<MediaItem> _history = [];
  static const String _key = 'watch_history';
  static ValueNotifier<int> listChanged = ValueNotifier(0);

  static List<MediaItem> get history => _history;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data != null) {
        final List decoded = jsonDecode(data);
        _history = decoded.map((e) => MediaItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading watch history: $e');
    }
  }

  static Future<void> restore(List<dynamic> data) async {
    try {
      _history = data.map((e) => MediaItem.fromJson(e)).toList();
      await save();
      listChanged.value++;
      debugPrint('📥 [WATCH HISTORY] Restored ${_history.length} items.');
    } catch (e) {
      debugPrint('Error restoring watch history: $e');
    }
  }

  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_history.map((e) => e.toJson()).toList());
      await prefs.setString(_key, data);
    } catch (e) {
      // Error saving watch history
    }
  }

  static void addItem(MediaItem item, {int? season, int? episode}) {
    _history.removeWhere((e) => e.id == item.id);
    _history.insert(0, item);
    if (_history.length > 20) {
      _history.removeLast();
    }

    // Update series progress if applicable
    if (item.mediaType == 'tv' && season != null && episode != null) {
      CollectionService.instance.updateProgress(item, season, episode);
    }

    // FIX: Defer notification to avoid "setState() or markNeedsBuild() called during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      listChanged.value++;
    });
    save(); // Auto-save
    SyncService.instance.syncWatchHistory();
  }

  static void removeItem(int id) {
    _history.removeWhere((e) => e.id == id);
    listChanged.value++;
    save();
    SyncService.instance.syncWatchHistory();
  }
}

