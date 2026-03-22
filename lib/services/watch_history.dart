import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

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
      print('Error loading watch history: $e');
    }
  }

  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_history.map((e) => e.toJson()).toList());
      await prefs.setString(_key, data);
    } catch (e) {
      print('Error saving watch history: $e');
    }
  }

  static void addItem(MediaItem item) {
    _history.removeWhere((e) => e.id == item.id);
    _history.insert(0, item);
    if (_history.length > 20) {
      _history.removeLast();
    }
    // FIX: Defer notification to avoid "setState() or markNeedsBuild() called during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      listChanged.value++;
    });
    save(); // Auto-save
  }
}
