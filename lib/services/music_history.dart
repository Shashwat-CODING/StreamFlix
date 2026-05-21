import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';
import 'sync_service.dart';

class MusicHistory {
  static List<SongModel> _history = [];
  static const String _key = 'music_history';
  static ValueNotifier<int> listChanged = ValueNotifier(0);

  static List<SongModel> get history => _history;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data != null) {
        final List decoded = jsonDecode(data);
        _history = decoded.map((e) => SongModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading music history: $e');
    }
  }

  static Future<void> restore(List<dynamic> data) async {
    try {
      _history = data.map((e) => SongModel.fromJson(e)).toList();
      await save();
      listChanged.value++;
      debugPrint('📥 [MUSIC HISTORY] Restored ${_history.length} items.');
    } catch (e) {
      debugPrint('Error restoring music history: $e');
    }
  }

  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_history.map((e) => e.toJson()).toList());
      await prefs.setString(_key, data);
    } catch (e) {
      // Error saving music history
    }
  }

  static void addItem(SongModel item) {
    _history.removeWhere((e) => e.id == item.id);
    _history.insert(0, item);
    if (_history.length > 30) {
      _history.removeLast();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      listChanged.value++;
    });
    save(); // Auto-save
    SyncService.instance.syncMusicHistory();
  }
}
