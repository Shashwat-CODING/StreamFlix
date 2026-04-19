import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

class BookmarkService {
  static List<MediaItem> _bookmarks = [];
  static const String _key = 'bookmarks_list';
  static ValueNotifier<int> listChanged = ValueNotifier(0);

  static List<MediaItem> get bookmarks => _bookmarks;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data != null) {
        final List decoded = jsonDecode(data);
        _bookmarks = decoded.map((e) => MediaItem.fromJson(e)).toList();
      }
    } catch (e) {
      // Error loading bookmarks
    }
  }

  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_bookmarks.map((e) => e.toJson()).toList());
      await prefs.setString(_key, data);
    } catch (e) {
      // Error saving bookmarks
    }
  }

  static bool isBookmarked(int id) {
    return _bookmarks.any((e) => e.id == id);
  }

  static void toggleBookmark(MediaItem item) {
    final index = _bookmarks.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      _bookmarks.removeAt(index);
    } else {
      _bookmarks.insert(0, item);
    }
    listChanged.value++;
    save();
  }
}
