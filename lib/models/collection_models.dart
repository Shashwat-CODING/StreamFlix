import '../models/media_item.dart';

class MediaCollection {
  final String id;
  final String name;
  final String? description;
  final List<MediaItem> items;
  final DateTime createdAt;

  MediaCollection({
    required this.id,
    required this.name,
    this.description,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'items': items.map((i) => i.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory MediaCollection.fromJson(Map<String, dynamic> json) => MediaCollection(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    items: (json['items'] as List?)?.map((i) => MediaItem.fromJson(i)).toList() ?? [],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}

class SeriesProgress {
  final int seriesId;
  final String title;
  final String? posterPath;
  final Map<int, List<int>> watchedEpisodes; // Season -> List of Episode Numbers
  final DateTime lastWatched;

  SeriesProgress({
    required this.seriesId,
    required this.title,
    this.posterPath,
    required this.watchedEpisodes,
    required this.lastWatched,
  });

  Map<String, dynamic> toJson() {
    String lastEpisodeStr = 'S01E01';
    if (watchedEpisodes.isNotEmpty) {
      final sortedSeasons = watchedEpisodes.keys.toList()..sort();
      if (sortedSeasons.isNotEmpty) {
        final lastSeason = sortedSeasons.last;
        final episodes = watchedEpisodes[lastSeason];
        if (episodes != null && episodes.isNotEmpty) {
          final sortedEpisodes = List<int>.from(episodes)..sort();
          final lastEpisode = sortedEpisodes.last;
          lastEpisodeStr = 'S${lastSeason.toString().padLeft(2, '0')}E${lastEpisode.toString().padLeft(2, '0')}';
        }
      }
    }

    return {
      'seriesId': seriesId,
      'title': title,
      'posterPath': posterPath,
      'watchedEpisodes': watchedEpisodes.map((k, v) => MapEntry(k.toString(), v)),
      'lastWatched': lastWatched.toIso8601String(),
      'lastWatchedEpisode': lastEpisodeStr,
      'timestamp': lastWatched.millisecondsSinceEpoch / 1000,
    };
  }

  factory SeriesProgress.fromJson(Map<String, dynamic> json) {
    final Map<int, List<int>> watched = {};
    if (json['watchedEpisodes'] != null) {
      (json['watchedEpisodes'] as Map).forEach((k, v) {
        watched[int.parse(k.toString())] = List<int>.from(v);
      });
    } else if (json['lastWatchedEpisode'] != null) {
      final match = RegExp(r'[sS](\d+)[eE](\d+)').firstMatch(json['lastWatchedEpisode'].toString());
      if (match != null) {
        final s = int.tryParse(match.group(1) ?? '') ?? 1;
        final e = int.tryParse(match.group(2) ?? '') ?? 1;
        watched[s] = [e];
      }
    }
    final lastWatchedTime = json['lastWatched'] != null 
        ? DateTime.parse(json['lastWatched'])
        : (json['timestamp'] != null 
            ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt() * 1000)
            : DateTime.now());

    return SeriesProgress(
      seriesId: json['seriesId'] ?? json['id'] ?? 0,
      title: json['title'] ?? 'Unknown TV Show',
      posterPath: json['posterPath'] ?? json['poster_path'],
      watchedEpisodes: watched,
      lastWatched: lastWatchedTime,
    );
  }
}
