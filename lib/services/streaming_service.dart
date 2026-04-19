import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_models.dart';
import '../models/media_item.dart';
import '../models/download_item.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'api_service.dart';
import 'permission_service.dart';

class StreamingService {
  StreamingService._();
  static final StreamingService instance = StreamingService._();

  void _logReq(String url) => debugPrint('🚀 [STREAM REQ] $url');
  void _logRes(String url, int code) => debugPrint('${code == 200 ? '✅' : '❌'} [STREAM RES] $code: $url');
  void _logErr(String url, dynamic e) => debugPrint('💥 [STREAM ERR] $e: $url');

  void _logInfo(String msg) => debugPrint('ℹ️ [Download INFO]: $msg');

  Stream<List<StreamSource>> getSources(String mediaType, int tmdbId, {int? season, int? episode}) async* {
    if (!ApiService.instance.isConfigured) {
      yield [];
      return;
    }
    _logInfo('Finding sources for $mediaType ($tmdbId)...');
    final query = (mediaType == 'tv' && season != null && episode != null)
        ? '&season=$season&episode=$episode'
        : '';
    final streamingBase = ApiService.instance.streamingBase;

    // Primary Servers (Standardized: 1, 3, 4, 5, 6, 9)
    final List<(int, String, Duration)> primaryConfigs = [
      (6, '$streamingBase/6/$mediaType?id=$tmdbId$query', const Duration(seconds: 50)),
      (1, '$streamingBase/1/$mediaType?id=$tmdbId$query', const Duration(seconds: 30)),
      (3, '$streamingBase/3/$mediaType?id=$tmdbId$query', const Duration(seconds: 30)),
      (4, '$streamingBase/4/$mediaType?id=$tmdbId$query', const Duration(seconds: 30)),
      (5, '$streamingBase/5/$mediaType?id=$tmdbId$query', const Duration(seconds: 35)),
      (9, '$streamingBase/9/$mediaType?id=$tmdbId$query', const Duration(seconds: 60)),
    ];

    final client = http.Client();
    final controller = StreamController<List<StreamSource>>();
    int pending = primaryConfigs.length;

    try {
      for (final c in primaryConfigs) {
        _fetchSources(client, c.$2, c.$1, timeout: c.$3).then((sources) {
          if (sources.isNotEmpty) {
            controller.add(sources);
          }
        }).catchError((_) {}).whenComplete(() async {
          pending--;
          if (pending == 0) {
            controller.close();
            client.close();
          }
        });
      }
      yield* controller.stream;
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  Future<List<StreamSource>> getSpecificServerSources(String mediaType, int tmdbId, int serverId, {int? season, int? episode}) async {
    if (!ApiService.instance.isConfigured) return [];
    
    final query = (mediaType == 'tv' && season != null && episode != null)
        ? '&season=$season&episode=$episode'
        : '';
    final url = '${ApiService.instance.streamingBase}/$serverId/$mediaType?id=$tmdbId$query';
    
    final client = http.Client();
    try {
      final sources = await _fetchSources(client, url, serverId, timeout: const Duration(seconds: 40));
      return sources;
    } finally {
      client.close();
    }
  }

  Future<List<StreamSource>> _fetchSources(http.Client client, String url, int serverId, {Duration timeout = const Duration(seconds: 15)}) async {
    try {
      _logReq(url);
      final res = await client.get(Uri.parse(url)).timeout(timeout);
      _logRes(url, res.statusCode);
      if (res.statusCode != 200) return [];
      
      final dynamic decoded = jsonDecode(res.body);
      List<dynamic> list = [];
      
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map) {
        // Fallback for legacy wrappers if any still exist
        list = decoded['streams'] ?? decoded['data']?['sources'] ?? [];
      }

      return list.map((i) {
        final s = StreamSource.fromJson(i);
        // Inject current serverId if missing or 0
        return StreamSource(
          quality: s.quality,
          url: s.url,
          source: s.source,
          serverId: s.serverId == 0 ? serverId : s.serverId,
          referer: s.referer,
          origin: s.origin,
          headers: s.headers,
          sizeText: s.sizeText,
          size: s.size,
          subtitles: s.subtitles,
          noHeaders: s.noHeaders,
          fileSize: s.fileSize,
          type: s.type,
          language: s.language,
          priority: s.priority,
        );
      }).where((s) => s.url.isNotEmpty).toList();
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<StreamSource>> fetchDownloadSources(String mediaType, int tmdbId, {int? season, int? episode}) async {
    final query = (mediaType == 'tv' && season != null && episode != null)
        ? '&season=$season&episode=$episode'
        : '';
    final url = '${ApiService.instance.downloadBase}/$mediaType?id=$tmdbId$query';
    
    try {
      _logReq(url);
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      _logRes(url, res.statusCode);
      if (res.statusCode != 200) return [];

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! List) return [];

      return decoded.map((i) {
        final s = StreamSource.fromJson(i);
        return StreamSource(
          quality: s.quality,
          url: s.url,
          source: (s.source == 'Unknown' && i['metadata'] != null) ? i['metadata'] : s.source,
          serverId: 0, // Dedicated download server
          referer: s.referer,
          origin: s.origin,
          headers: s.headers,
          sizeText: i['sizeText']?.toString() ?? s.sizeText,
          type: s.type,
          language: s.language,
        );
      }).where((s) => s.url.isNotEmpty).toList();
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<Subtitle>> fetchSubtitles(String mediaType, int tmdbId, {int? season, int? episode}) async {
    if (!ApiService.instance.isConfigured) return [];
    final query = (mediaType == 'tv' && season != null && episode != null) ? '&s=$season&e=$episode' : '';
    final url = '${ApiService.instance.streamingBase}/11/$mediaType?id=$tmdbId$query';
    _logReq(url);
    try {
      final res = await http.get(Uri.parse(url));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['subtitles'] != null) {
          return (data['subtitles'] as List).map((j) => Subtitle.fromJson(j)).toList();
        }
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  // ── DOWNLOADING METHODS ───────────────────────────────────────────────────

  final Dio _dio = Dio();
  List<DownloadItem> _downloads = [];
  final Map<String, CancelToken> _cancelTokens = {};
  
  List<DownloadItem> get downloads => _downloads;
  static ValueNotifier<int> listChanged = ValueNotifier(0);

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final _mediaStore = MediaStore();
  bool _isNotifInitialized = false;

  Future<void> _initNotifications() async {
    if (_isNotifInitialized) return;
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await _notificationsPlugin.initialize(initializationSettings);
      
      // Create notification channel for Android O+
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'drishya_downloads', // id
          'Downloads', // title
          description: 'Notifications for download progress', // description
          importance: Importance.low,
          showBadge: false,
        );

        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
      
      _isNotifInitialized = true;
      _logInfo('Notification service initialized.');
    } catch (e) {
      _logErr('Notification init', e);
    }
  }

  Future<void> initDownloads() async {
    await _initNotifications();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_downloads');
    List<DownloadItem> localItems = [];
    bool restoredFromExternal = false;

    if (saved != null) {
      try {
        final List decoded = jsonDecode(saved);
        localItems = decoded.map((e) => DownloadItem.fromJson(e)).toList();
      } catch (e) {
        _logErr("Local Restore", e);
      }
    }

    // -- EXTERNAL METADATA RESTORE (Persistent Backup) --
    if (Platform.isAndroid) {
      try {
        final List<String> searchPaths = [
          '/storage/emulated/0/Download/Drishya',
          '/storage/emulated/0/Download',
          '/sdcard/Download/Drishya',
        ];

        final List<File> FoundMetaFiles = [];
        for (final path in searchPaths) {
          final dir = Directory(path);
          if (await dir.exists()) {
             final List<FileSystemEntity> entities = dir.listSync();
             for (final e in entities) {
               if (e is File && e.path.toLowerCase().contains('metadata') && e.path.toLowerCase().endsWith('.json')) {
                 FoundMetaFiles.add(e);
               }
             }
          }
        }

        if (FoundMetaFiles.isNotEmpty) {
          // Sort by modified time to get the latest one first, or just merge all
          FoundMetaFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          
          final Map<String, DownloadItem> merged = {};
          // Merge from oldest to newest so newest wins if same ID
          for (final file in FoundMetaFiles.reversed) {
            try {
              final content = await file.readAsString();
              final List decoded = jsonDecode(content);
              final List<DownloadItem> items = decoded.map((e) => DownloadItem.fromJson(e)).toList();
              for (var i in items) {
                merged[i.id] = i;
              }
              restoredFromExternal = true;
            } catch (e) {
              _logErr("Failed to read ${file.path}", e);
            }
          }

          // Merge with local items
          for (var i in localItems) {
            merged[i.id] = i; 
          }
          localItems = merged.values.toList();
          _logInfo("Restored ${localItems.length} downloads from ${FoundMetaFiles.length} external metadata files.");
        } else {
          _logInfo("No external metadata.json found.");
        }
      } catch (e) {
        _logErr("Metadata Restore", e);
      }
    }

    // Filter to only items that actually exist on disk (validate storage)
    final List<DownloadItem> verifiedItems = [];
    for (var item in localItems) {
       // Since the app might be reinstalled, absolute paths in 'savedPath' might be invalid
       // if they were internal. But for backups, they SHOULD be in public storage.
       if (await File(item.savedPath).exists()) {
          verifiedItems.add(item);
       } else {
          _logInfo("Skipping entry ${item.mediaItem.title} - File not found at ${item.savedPath}");
       }
    }
    
    _downloads = verifiedItems;
    
    // Safety check: Only save if we actually have data or if we successfully restored from external.
    // This prevents overwriting a hidden/unreadable external backup with an empty local state.
    if (_downloads.isNotEmpty || restoredFromExternal) {
      await _saveDownloads(); 
    }
  }

  Future<void> _saveDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _downloads.map((e) => e.toJson()).toList();
    final encoded = jsonEncode(jsonList);
    
    await prefs.setString('saved_downloads', encoded);

    // Save to External Storage Metadata (Sync)
    if (Platform.isAndroid) {
      try {
        final internalDir = await getApplicationSupportDirectory();
        final tempMetaFile = File('${internalDir.path}/metadata.json');
        await tempMetaFile.writeAsString(encoded);
        
        // Save to public Download folder using MediaStore
        await _mediaStore.saveFile(
          tempFilePath: tempMetaFile.path,
          dirType: DirType.download,
          dirName: DirName.download,
        );
      } catch (e) {
        _logErr("Metadata Sync Save", e);
      }
    }
    
    listChanged.value++;
  }

  Future<void> startDownload(
    List<StreamSource> sources,
    MediaDetail item, {
    String? sourceLabel,
    int? season,
    int? episode,
  }) async {
    _logInfo("Starting download process for ${item.title}...");
    if (sources.isEmpty) throw Exception('No sources available for download.');
    
    if (Platform.isAndroid) {
      await PermissionService.requestAll();
    }

    final internalDir = await getApplicationSupportDirectory();
    final downloadDir = Directory('${internalDir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    String sanitizedTitle = item.title.replaceAll(RegExp(r'[^\w\s]+'), '').trim().replaceAll(' ', '_');
    if (season != null && episode != null) {
      sanitizedTitle += '_S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';
    }
    const ext = 'mp4'; 
    
    final String downloadId = season != null && episode != null 
        ? '${item.id}_s${season}_e${episode}_${DateTime.now().millisecondsSinceEpoch}'
        : '${item.id}_${item.mediaType}_${DateTime.now().millisecondsSinceEpoch}';
    
    // We download to internal storage first for easy resumption and process management
    String savePath = '${downloadDir.path}/$sanitizedTitle.$ext';
    int counter = 1;
    while (await File(savePath).exists()) {
      savePath = '${downloadDir.path}/${sanitizedTitle}_$counter.$ext';
      counter++;
    }


    // No verification needed for dedicated download sources as they are pre-verified
    final source = sources.first;
    final Map<String, String> headers = Map<String, String>.from(source.headers ?? {});
    headers.putIfAbsent('User-Agent', () => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36');
    if (source.referer != null) headers.putIfAbsent('Referer', () => source.referer!);
    if (source.origin != null) headers.putIfAbsent('Origin', () => source.origin!);

    final downloadItem = DownloadItem(
      id: downloadId,
      mediaItem: item,
      url: source.url,
      savedPath: savePath,
      totalBytes: -1,
      headers: headers,
      backupUrls: sources.map((e) => e.url).toList(),
      currentSourceIndex: 0,
      sourceLabel: sourceLabel,
      status: DownloadStatus.downloading,
    );

    _downloads.insert(0, downloadItem);
    await _saveDownloads();
    _proceedDownload(downloadItem);
    return;
  }

  void _showNotification(DownloadItem item) {
    if (!_isNotifInitialized || item.status == DownloadStatus.cancelled) return;

    try {
      final int progress = item.totalBytes > 0 ? ((item.downloadedBytes / item.totalBytes) * 100).toInt() : 0;
      
      String body = '';
      int maxProgress = 100;
      bool showProgress = false;

      if (item.status == DownloadStatus.downloading) {
        body = 'Downloading... $progress%';
        showProgress = true;
      } else if (item.status == DownloadStatus.completed) {
        body = 'Download Complete!';
      } else if (item.status == DownloadStatus.failed) {
        body = 'Download Failed/Paused.';
      }

      _notificationsPlugin.show(
        item.id.hashCode,
        'Drishya: ${item.mediaItem.title}',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'drishya_downloads',
            'Downloads',
            channelDescription: 'Notifications for download progress',
            importance: Importance.low,
            priority: Priority.low,
            showProgress: showProgress,
            maxProgress: maxProgress,
            progress: progress,
            onlyAlertOnce: true,
          ),
        ),
      );
    } catch (e) {
      _logErr('Show Notification', e);
    }
  }

  Future<void> _proceedDownload(DownloadItem item) async {
    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    item.status = DownloadStatus.downloading;
    await _saveDownloads();

    int downloadedSoFar = 0;
    final file = File(item.savedPath);

    if (await file.exists()) {
      downloadedSoFar = await file.length();
    }

    try {
      final options = Options(
        headers: {
          if (item.headers != null) ...item.headers!,
          if (downloadedSoFar > 0) 'Range': 'bytes=$downloadedSoFar-',
        },
        validateStatus: (status) => status != null && status < 500,
      );

      DateTime lastSave = DateTime.now();

      _logInfo("Initiating download for ${item.mediaItem.title} from ${item.url}");
      if (downloadedSoFar > 0) {
        _logInfo("Resuming from byte $downloadedSoFar (Total: ${item.totalBytes})");
      }

      await _dio.download(
        item.url,
        item.savedPath,
        options: options,
        cancelToken: cancelToken,
        deleteOnError: false, // critical for resumable downloads
        onReceiveProgress: (received, total) async {
          // If total is -1, we don't know the size, or it's giving size of this chunk. 
          // Dio calculates total properly if server supports it. 
          int currentBytes = downloadedSoFar > 0 ? (downloadedSoFar + received) : received;
          item.downloadedBytes = currentBytes;

          if (item.totalBytes <= 0 && total != -1) {
             item.totalBytes = downloadedSoFar > 0 ? downloadedSoFar + total : total;
          }

          if (DateTime.now().difference(lastSave).inSeconds > 1) {
            lastSave = DateTime.now();
            await _saveDownloads();
            listChanged.value++;
            _showNotification(item);
          }
        },
      );

      item.status = DownloadStatus.completed;
      item.downloadedBytes = item.totalBytes;
      _logInfo("Download internal complete for ${item.mediaItem.title}. Saving to MediaStore...");
      
      // Save to public storage
      if (Platform.isAndroid) {
        try {
          final String fileName = item.savedPath.split('/').last;
          final SaveInfo? saveInfo = await _mediaStore.saveFile(
            tempFilePath: item.savedPath,
            dirType: DirType.video,
            dirName: DirName.movies,
          );
          
          if (saveInfo != null) {
            _logInfo("Saved to public MediaStore successfully: ${saveInfo.name}");
            // Update savedPath to point to the public location for future indexing
            // Note: on Android 10+, direct path access to other app's files is restricted,
            // but for our own files in public folders, it often works or we use MediaStore URI.
            // For now, let's point to the likely public path.
            final publicPath = "/storage/emulated/0/Movies/Drishya/$fileName";
            final tempFile = File(item.savedPath);
            
            item.savedPath = publicPath;
            if (await tempFile.exists()) {
              await tempFile.delete(); // Cleanup internal storage
            }
          }
        } catch (e) {
          _logErr("MediaStore Save", e);
        }
      }

      await _saveDownloads();
      listChanged.value++;
      _showNotification(item);

    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        item.status = DownloadStatus.paused;
      } else {
        // Automatic Source Fallback Logic
        if (item.currentSourceIndex + 1 < item.backupUrls.length) {
          item.currentSourceIndex++;
          item.url = item.backupUrls[item.currentSourceIndex];
          _logReq("Source ${item.currentSourceIndex - 1} failed halfway. Switching to next source: ${item.url}");
          // Try resuming recursively
          _cancelTokens.remove(item.id);
          return _proceedDownload(item);
        } else {
          item.status = DownloadStatus.failed;
          _logErr(item.url, "Download failed completely across all sources: $e");
        }
      }
      await _saveDownloads();
      listChanged.value++;
      _showNotification(item);
    } finally {
      if (_cancelTokens[item.id] == cancelToken) _cancelTokens.remove(item.id);
    }
  }

  void pauseDownload(String id) {
    _cancelTokens[id]?.cancel();
    final item = _downloads.firstWhere((e) => e.id == id);
    item.status = DownloadStatus.paused;
    _saveDownloads();
  }

  void resumeDownload(String id) {
    final item = _downloads.firstWhere((e) => e.id == id);
    if (item.status != DownloadStatus.completed) {
      _proceedDownload(item);
    }
  }

  void cancelDownload(String id) async {
    _cancelTokens[id]?.cancel();
    final item = _downloads.firstWhere((e) => e.id == id);
    item.status = DownloadStatus.cancelled;
    _downloads.removeWhere((e) => e.id == id);
    await _saveDownloads();

    final file = File(item.savedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
