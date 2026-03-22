import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

// Default headers used for servers that provide no auth headers (1, 3, 4, 5)
const String _kDefaultReferer = 'https://rivestream.app/';
const String _kDefaultOrigin = 'https://rivestream.app';

class Subtitle {
  final String url;
  final String lang;
  Subtitle({required this.url, required this.lang});

  Map<String, String> toJson() => {'url': url, 'lang': lang};
  factory Subtitle.fromJson(Map<String, dynamic> json) => Subtitle(
    url: json['url']?.toString() ?? '',
    lang: (json['lang'] ?? json['language'] ?? 'Unknown').toString(),
  );
}

class StreamSource {
  final String quality;
  final String url;
  final String source;
  final String format;
  final int serverId;
  final String? referer;
  final String? origin;
  final String? size;
  final List<Subtitle>? subtitles;
  final Map<String, String>? headers;
  final int priority;

  /// When true, the player must send NO headers at all for this source.
  /// Used for Server 5 (VixSrc) which rejects requests with custom headers.
  final bool noHeaders;

  StreamSource({
    required this.quality,
    required this.url,
    required this.source,
    required this.format,
    required this.serverId,
    this.referer,
    this.origin,
    this.size,
    this.subtitles,
    this.headers,
    this.priority = 10,
    this.noHeaders = false,
  });

  /// Always resolves to a valid value — falls back to rivestream defaults.
  String get resolvedReferer =>
      (referer != null && referer!.isNotEmpty) ? referer! : _kDefaultReferer;
  String get resolvedOrigin =>
      (origin != null && origin!.isNotEmpty) ? origin! : _kDefaultOrigin;

  @override
  String toString() =>
      '[Server $serverId] quality=$quality | source=$source | '
      'format=$format | noHeaders=$noHeaders | referer=$resolvedReferer | '
      'url=${url.length > 70 ? "${url.substring(0, 70)}..." : url}';
}

class StreamingService {
  static const String _base =
      'https://laughing-potato-l01g.onrender.com/api/media';

  Stream<List<StreamSource>> getMovieSources(int tmdbId) =>
      _fetchAll('movie', tmdbId);

  Stream<List<StreamSource>> getTvSources(
    int tmdbId,
    int season,
    int episode,
  ) => _fetchAll('tv', tmdbId, season: season, episode: episode);

  Stream<List<StreamSource>> _fetchAll(
    String type,
    int tmdbId, {
    int? season,
    int? episode,
  }) async* {
    print('\n══════════════════════════════════════════');
    print(
      '🎬 Fetching sources | type=$type | tmdbId=$tmdbId | s=$season | e=$episode',
    );
    print('══════════════════════════════════════════');

    final query = (type == 'tv' && season != null && episode != null)
        ? '&season=$season&episode=$episode'
        : '';

    final List<(int, String, Duration)> configs = [
      (6, '$_base/6/$type?id=$tmdbId$query', const Duration(seconds: 50)),
      (1, '$_base/1/$type?id=$tmdbId$query', const Duration(seconds: 30)),
      (3, '$_base/3/$type?id=$tmdbId$query', const Duration(seconds: 30)),
      (4, '$_base/4/$type?id=$tmdbId$query', const Duration(seconds: 30)),
      (5, '$_base/5/$type?id=$tmdbId$query', const Duration(seconds: 30)),
      (9, '$_base/9/$type?id=$tmdbId$query', const Duration(seconds: 60)),
      (10, '$_base/10/$type?id=$tmdbId$query', const Duration(seconds: 60)),
    ];

    final client = http.Client();
    try {
      final List<Future<List<StreamSource>>> futures = configs
          .map((c) => _fetchSources(client, c.$2, c.$1, timeout: c.$3))
          .toList();

      int pending = futures.length;
      final controller = StreamController<List<StreamSource>>();

      for (final f in futures) {
        f
            .then((sources) {
              if (sources.isNotEmpty) controller.add(sources);
            })
            .catchError((_) {
              // Ignore individual errors to keep the stream going
            })
            .whenComplete(() {
              if (--pending == 0) {
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

  Future<List<StreamSource>> _fetchSources(
    http.Client client,
    String url,
    int serverId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    print('🌐 [Server $serverId] Fetching → $url');
    try {
      final res = await client.get(Uri.parse(url)).timeout(timeout);

      if (res.statusCode != 200) {
        print('❌ [Server $serverId] HTTP ${res.statusCode}');
        return [];
      }

      final Map<String, dynamic> data = jsonDecode(res.body);

      // ── Server 6 ─────────────────────────────────────────────────────────
      // Response:
      //   { "data": { "stream_url": "...", "source": "mapple",
      //               "headers": { "Referer": "https://mapple.uk",
      //                            "Origin":  "https://mapple.uk" } } }
      //
      // ✔ Uses its own headers from the response.
      // ✔ Returns exactly 1 source.
      // Rule: fails → server 6 blocked.
      if (serverId == 6) {
        final d = data['data'];
        final streams = data['streams'];

        if (d is Map<String, dynamic> && d['stream_url'] != null) {
          final headers = d['headers'] as Map<String, dynamic>?;
          final source = StreamSource(
            quality: 'Auto',
            url: d['stream_url'].toString(),
            source: (d['source']?.toString() ?? 'Mapple').toUpperCase(),
            format: 'hls',
            serverId: 6,
            referer: (headers?['Referer'] ?? headers?['referer'])?.toString(),
            origin: (headers?['Origin'] ?? headers?['origin'])?.toString(),
          );
          print(
            '  ✅ [Server 6] ${source.quality} | ${source.source} | referer=${source.resolvedReferer}',
          );
          return [source];
        } else if (streams is List && streams.isNotEmpty) {
          final List<StreamSource> result = [];
          for (final item in streams) {
            if (item is! Map<String, dynamic>) continue;
            final headers = item['headers'] as Map<String, dynamic>?;
            final source = StreamSource(
              quality: item['quality']?.toString() ?? 'Auto',
              url: item['url']?.toString() ?? '',
              source: (item['server'] ?? item['provider'] ?? 'Mapple')
                  .toString()
                  .toUpperCase(),
              format: 'hls',
              serverId: 6,
              referer: (headers?['Referer'] ?? headers?['referer'])?.toString(),
              origin: (headers?['Origin'] ?? headers?['origin'])?.toString(),
            );
            if (source.url.isNotEmpty) result.add(source);
          }
          if (result.isNotEmpty) {
            print('  ✅ [Server 6] Found ${result.length} sources via streams array');
            return result;
          }
        }

        print('❌ [Server 6] Unexpected response structure: $data');
        return [];
      }

      // ── Servers 1 & 3 ────────────────────────────────────────────────────
      // Response:
      //   { "data": { "sources": [
      //       { "quality": 480, "url": "https://proxy.valhallastream.../...",
      //         "source": "FlowCast", "format": "mp4", "size": "761620781" },
      //       { "quality": 360, "url": "...", ... }
      //   ] } }
      //
      // ✔ URL contains URL-encoded headers in query params — intentionally
      //   IGNORED. Default rivestream headers are used instead.
      // Rule: if any 1 source from this server fails → entire server blocked.
      if (serverId == 1 || serverId == 3) {
        final List? rawSources =
            (data['data'] as Map<String, dynamic>?)?['sources'] as List?;
        if (rawSources == null || rawSources.isEmpty) {
          print('⚠️  [Server $serverId] No sources in response');
          return [];
        }
        final List<StreamSource> result = [];
        for (final item in rawSources) {
          if (item is! Map<String, dynamic>) continue;
          final String itemUrl = item['url']?.toString() ?? '';
          if (itemUrl.isEmpty) continue;
          final dynamic q = item['quality'];
          final String quality = q is num
              ? '${q.toInt()}p'
              : q?.toString() ?? 'Unknown';
          final source = StreamSource(
            quality: quality,
            url: itemUrl,
            source: item['source']?.toString() ?? 'Unknown',
            format: item['format']?.toString() ?? 'mp4',
            serverId: serverId,
            referer: null, // resolvedReferer → rivestream default
            origin: null, // resolvedOrigin  → rivestream default
            size: item['size']?.toString(),
          );
          print(
            '  ✅ [Server $serverId] ${source.quality} | ${source.source} | referer=${source.resolvedReferer}',
          );
          result.add(source);
        }
        return result;
      }

      // ── Server 4 ─────────────────────────────────────────────────────────
      // Response:
      //   { "data": { "sources": [
      //       { "url": "https://cfbw.p2l.workers.dev/...",
      //         "quality": "HLS 1", "source": "Guru", "format": "hls" },
      //       { "url": "...", "quality": "HLS 2", ... },
      //       ...
      //   ] } }
      //
      // ✔ No headers in response → rivestream defaults used.
      // Rule: if any 1 HLS source fails → entire server blocked.
      if (serverId == 4) {
        final List? rawSources =
            (data['data'] as Map<String, dynamic>?)?['sources'] as List?;
        if (rawSources == null || rawSources.isEmpty) {
          print('⚠️  [Server 4] No sources in response');
          return [];
        }
        final List<StreamSource> result = [];
        for (final item in rawSources) {
          if (item is! Map<String, dynamic>) continue;
          final String itemUrl = item['url']?.toString() ?? '';
          if (itemUrl.isEmpty) continue;
          final source = StreamSource(
            quality: item['quality']?.toString() ?? 'HLS',
            url: itemUrl,
            source: item['source']?.toString() ?? 'Guru',
            format: item['format']?.toString() ?? 'hls',
            serverId: 4,
            priority: item['priority'] is int ? item['priority'] : 1,
            referer: null, // resolvedReferer → rivestream default
            origin: null, // resolvedOrigin  → rivestream default
          );
          print(
            '  ✅ [Server 4] ${source.quality} | ${source.source} | referer=${source.resolvedReferer}',
          );
          result.add(source);
        }
        return result;
      }

      // ── Server 5 ─────────────────────────────────────────────────────────
      // Response:
      //   { "streams": [
      //       { "url": "https://vixsrc.to/playlist/....m3u8?...",
      //         "name": "WebStreamr | Hayduk 🌐 🇺🇸 1080p", ... },
      //       ... (many other non-vixsrc entries — all discarded)
      //   ] }
      //
      // ✔ Only the FIRST vixsrc.to URL is used — everything else is ignored.
      // ✔ No headers in response → rivestream defaults used.
      // Rule: vixsrc fails → server 5 blocked.
      if (serverId == 5) {
        final List? streams = data['streams'] as List?;
        if (streams == null || streams.isEmpty) {
          print('⚠️  [Server 5] No streams in response');
          return [];
        }
        for (final item in streams) {
          if (item is! Map<String, dynamic>) continue;
          final String itemUrl = item['url']?.toString() ?? '';
          if (!itemUrl.contains('vixsrc')) continue;
          final String name = item['name']?.toString() ?? '';
          final match = RegExp(r'(\d{3,4}p)').firstMatch(name);
          final String quality = match != null ? match.group(1)! : '1080p';
          final source = StreamSource(
            quality: quality,
            url: itemUrl,
            source: 'VixSrc',
            format: 'hls',
            serverId: 5,
            referer: null,
            origin: null,
            noHeaders: true, // VixSrc rejects requests with custom headers
          );
          print('  ✅ [Server 5] ${source.quality} | VixSrc | noHeaders=true');
          return [source]; // Only ever one vixsrc entry
        }
        print('⚠️  [Server 5] No vixsrc URL found');
        return [];
      }

      // ── Server 9 ─────────────────────────────────────────────────────────
      // Response:
      //   { "success": true, "streams": [
      //       { "server": "FuckIt-sr12 (Hindi)", "url": "...", "quality": "Hindi",
      //         "headers": { "Referer": "..." }, "provider": "FuckIt" }
      //     ], "sr": 12 }
      if (serverId == 9) {
        final List? streams = data['streams'] as List?;
        if (streams == null || streams.isEmpty) {
          print('⚠️  [Server 9] No streams in response');
          return [];
        }

        final List<Subtitle> subs =
            (data['subtitles'] as List?)
                ?.map((s) => Subtitle.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [];

        final List<StreamSource> result = [];
        for (final item in streams) {
          if (item is! Map<String, dynamic>) continue;
          final headers = item['headers'] as Map<String, dynamic>?;
          final source = StreamSource(
            quality: item['quality']?.toString() ?? 'Auto',
            url: item['url']?.toString() ?? '',
            source: item['server']?.toString() ?? 'Server 9',
            format: item['type']?.toString() == 'm3u8'
                ? 'hls'
                : (item['type']?.toString() ?? 'hls'),
            serverId: 9,
            referer: (headers?['Referer'] ?? headers?['referer'])?.toString(),
            origin: (headers?['origin'] ?? headers?['Origin'])?.toString(),
            subtitles: subs,
          );
          if (source.url.isNotEmpty) {
            print(
              '  ✅ [Server 9] ${source.quality} | ${source.source} | subs=${subs.length}',
            );
            result.add(source);
          }
        }
        return result;
      }

      // ── Server 10 (Nxsha) ────────────────────────────────────────────────
      if (serverId == 10) {
        final List? streams = data['streams'] as List?;
        if (streams == null || streams.isEmpty) {
          print('⚠️  [Server 10] No streams in response');
          return [];
        }

        final List<StreamSource> result = [];
        for (final item in streams) {
          if (item is! Map<String, dynamic>) continue;

          final String itemUrl = item['url']?.toString() ?? '';
          if (itemUrl.isEmpty) continue;

          // Headers are optional in the new format
          final rawHeaders = item['headers'] as Map<String, dynamic>?;
          final Map<String, String> parsedHeaders = {};
          if (rawHeaders != null) {
            rawHeaders.forEach((key, value) {
              parsedHeaders[key.toString()] = value.toString();
            });
          }

          // Format normalization: m3u8 -> hls
          final String rawType = item['type']?.toString().toLowerCase() ?? 'hls';
          final String format = (rawType == 'm3u8' || rawType == 'hls') ? 'hls' : 'mp4';

          // Source name normalization
          final String sourceName = (item['server'] ?? item['provider'] ?? 'Nxsha')
              .toString()
              .toUpperCase();

          final source = StreamSource(
            quality: item['quality']?.toString() ?? 'Auto',
            url: itemUrl,
            source: sourceName,
            format: format,
            serverId: 10,
            headers: parsedHeaders,
            referer: parsedHeaders['Referer'] ?? parsedHeaders['referer'],
            origin: parsedHeaders['Origin'] ?? parsedHeaders['origin'],
            size: item['size']?.toString(),
          );

          if (source.url.isNotEmpty) {
            print(
              '  ✅ [Server 10] ${source.quality} | ${source.source} | format=${source.format}',
            );
            result.add(source);
          }
        }
        return result;
      }

      print('⚠️  Unknown serverId=$serverId — skipping');
      return [];
    } catch (e) {
      print('❌ [Server $serverId] Exception: $e');
      return [];
    }
  }
}
