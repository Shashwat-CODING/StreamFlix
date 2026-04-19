import 'media_item.dart';

enum DownloadStatus { downloading, paused, completed, failed, cancelled }

class DownloadItem {
  final String id; // Unique ID (e.g., tmdbId + season + episode)
  final MediaDetail mediaItem;
  String url;
  String savedPath; // Local path where it's saved
  int totalBytes;
  int downloadedBytes;
  DownloadStatus status;
  Map<String, String>? headers; // Headers needed if we resume
  List<String> backupUrls;      // Extra fallback sources
  int currentSourceIndex;
  String? sourceLabel; // Label for the source (e.g., "1" or "2")

  DownloadItem({
    required this.id,
    required this.mediaItem,
    required this.url,
    required this.savedPath,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.downloading,
    this.headers,
    this.backupUrls = const [],
    this.currentSourceIndex = 0,
    this.sourceLabel,
  });

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaItem': mediaItem.toJson(),
      'url': url,
      'savedPath': savedPath,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'status': status.index,
      'headers': headers,
      'backupUrls': backupUrls,
      'currentSourceIndex': currentSourceIndex,
      'sourceLabel': sourceLabel,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      mediaItem: MediaDetail.fromJson(json['mediaItem']),
      url: json['url'] as String,
      savedPath: json['savedPath'] as String,
      totalBytes: json['totalBytes'] ?? 0,
      downloadedBytes: json['downloadedBytes'] ?? 0,
      status: DownloadStatus.values[json['status'] ?? 0],
      headers: (json['headers'] as Map?)?.cast<String, String>(),
      backupUrls: (json['backupUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      currentSourceIndex: json['currentSourceIndex'] ?? 0,
      sourceLabel: json['sourceLabel'] as String?,
    );
  }
}
