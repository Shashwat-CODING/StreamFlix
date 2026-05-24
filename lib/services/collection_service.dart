import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/collection_models.dart';
import '../models/media_item.dart';
import 'sync_service.dart';

class CollectionService extends ChangeNotifier {
  static final CollectionService instance = CollectionService._();
  CollectionService._();

  List<MediaCollection> _collections = [];
  Map<int, SeriesProgress> _seriesProgress = {};

  List<MediaCollection> get collections => _collections;
  Map<int, SeriesProgress> get seriesProgress => _seriesProgress;

  static const String _collectionKey = 'media_collections';
  static const String _progressKey = 'series_progress';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Collections
    final cData = prefs.getString(_collectionKey);
    if (cData != null) {
      final List decoded = jsonDecode(cData);
      _collections = decoded.map((e) => MediaCollection.fromJson(e)).toList();
    }

    // Load Progress
    final prData = prefs.getString(_progressKey);
    if (prData != null) {
      final Map<String, dynamic> decoded = jsonDecode(prData);
      _seriesProgress = decoded.map((k, v) => MapEntry(int.parse(k), SeriesProgress.fromJson(v)));
    }
    
    notifyListeners();
  }

  void restore(List<dynamic> collections, Map<String, dynamic> progress) {
    _collections = collections.map((e) => MediaCollection.fromJson(e)).toList();
    _seriesProgress = progress.map((k, v) => MapEntry(int.parse(k), SeriesProgress.fromJson(v)));
    _saveCollections();
    _saveProgress();
    notifyListeners();
  }



  Future<void> _saveCollections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_collectionKey, jsonEncode(_collections.map((e) => e.toJson()).toList()));
    notifyListeners();
    SyncService.instance.syncCollections();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressKey, jsonEncode(_seriesProgress.map((k, v) => MapEntry(k.toString(), v.toJson()))));
    notifyListeners();
    SyncService.instance.syncProgress();
  }



  // Collection Methods
  void createCollection(String name, {String? description}) {
    final collection = MediaCollection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      items: [],
      createdAt: DateTime.now(),
    );
    _collections.add(collection);
    _saveCollections();
  }

  void deleteCollection(String id) {
    _collections.removeWhere((c) => c.id == id);
    _saveCollections();
  }

  void addItemToCollection(String collectionId, MediaItem item) {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      if (!_collections[index].items.any((i) => i.id == item.id && i.mediaType == item.mediaType)) {
        _collections[index].items.add(item);
        _saveCollections();
      }
    }
  }

  void removeItemFromCollection(String collectionId, int itemId, String mediaType) {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      _collections[index].items.removeWhere((i) => i.id == itemId && i.mediaType == mediaType);
      _saveCollections();
    }
  }

  // Series Progress Methods
  void updateProgress(MediaItem item, int season, int episode) {
    if (item.mediaType != 'tv') return;

    final progress = _seriesProgress[item.id] ?? SeriesProgress(
      seriesId: item.id,
      title: item.title,
      posterPath: item.posterPath,
      watchedEpisodes: {},
      lastWatched: DateTime.now(),
    );

    final episodes = progress.watchedEpisodes[season] ?? [];
    if (!episodes.contains(episode)) {
      episodes.add(episode);
      progress.watchedEpisodes[season] = episodes;
    }

    _seriesProgress[item.id] = SeriesProgress(
      seriesId: progress.seriesId,
      title: progress.title,
      posterPath: progress.posterPath,
      watchedEpisodes: progress.watchedEpisodes,
      lastWatched: DateTime.now(),
    );

    _saveProgress();
  }

  bool isEpisodeWatched(int seriesId, int season, int episode) {
    final progress = _seriesProgress[seriesId];
    if (progress == null) return false;
    return progress.watchedEpisodes[season]?.contains(episode) ?? false;
  }

  void removeSeriesProgress(int seriesId) {
    if (_seriesProgress.containsKey(seriesId)) {
      _seriesProgress.remove(seriesId);
      _saveProgress();
    }
  }
}
