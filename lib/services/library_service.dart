import 'package:flutter/foundation.dart';
import '../services/tmdb_service.dart';

class LibraryService extends ChangeNotifier {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  final List<TmdbItem> _watchLater = [];
  final List<TmdbItem> _history = [];

  List<TmdbItem> get watchLater => List.unmodifiable(_watchLater);
  List<TmdbItem> get history => List.unmodifiable(_history);

  bool isInWatchLater(TmdbItem item) => _watchLater.any((e) => e.id == item.id && e.mediaType == item.mediaType);
  void addToWatchLater(TmdbItem item) {
    if (!isInWatchLater(item)) {
      _watchLater.insert(0, item);
      notifyListeners();
    }
  }
  void removeFromWatchLater(TmdbItem item) {
    _watchLater.removeWhere((e) => e.id == item.id && e.mediaType == item.mediaType);
    notifyListeners();
  }

  void addToHistory(TmdbItem item) {
    _history.removeWhere((e) => e.id == item.id && e.mediaType == item.mediaType);
    _history.insert(0, item);
    if (_history.length > 200) _history.removeLast();
    notifyListeners();
  }
}


