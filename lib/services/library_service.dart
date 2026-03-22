import 'package:flutter/foundation.dart';
import '../models/media_item.dart';

class LibraryService extends ChangeNotifier {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  final List<MediaItem> _watchLater = [];
  final List<MediaItem> _history = [];

  List<MediaItem> get watchLater => List.unmodifiable(_watchLater);
  List<MediaItem> get history => List.unmodifiable(_history);

  bool isInWatchLater(MediaItem item) => _watchLater.any((e) => e.id == item.id && e.mediaType == item.mediaType);
  void addToWatchLater(MediaItem item) {
    if (!isInWatchLater(item)) {
      _watchLater.insert(0, item);
      notifyListeners();
    }
  }
  void removeFromWatchLater(MediaItem item) {
    _watchLater.removeWhere((e) => e.id == item.id && e.mediaType == item.mediaType);
    notifyListeners();
  }

  void addToHistory(MediaItem item) {
    _history.removeWhere((e) => e.id == item.id && e.mediaType == item.mediaType);
    _history.insert(0, item);
    if (_history.length > 200) _history.removeLast();
    notifyListeners();
  }
}


