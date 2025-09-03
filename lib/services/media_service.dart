import 'dart:convert';
import 'package:http/http.dart' as http;

class MediaService {
  MediaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Dynamic stream domain provider
  static const String _streamDomainEndpoint = 'https://dawn-violet-2368.bob17040246.workers.dev/';
  // Base site used for Origin/Referer similar to JS logic
  static const String _baseUrl = 'https://allmovieland.link';

  // Headers that mimic a modern desktop browser to avoid bot blocks.
  Map<String, String> _browserHeaders({String? origin, String? referer, String? csrf, bool json = false}) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
      'Accept': json
          ? '*/*'
          : 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'DNT': '1',
      'Sec-Fetch-Dest': json ? 'empty' : 'document',
      'Sec-Fetch-Mode': json ? 'cors' : 'navigate',
      'Sec-Fetch-Site': json ? 'same-origin' : 'none',
      if (!json) 'Sec-Fetch-User': '?1',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };
    if (origin != null) headers['Origin'] = origin;
    if (referer != null) headers['Referer'] = referer;
    if (csrf != null) headers['X-Csrf-Token'] = csrf;
    return headers;
  }

  Future<String> _discoverPlayerDomain() async {
    // Try JSON endpoint first (accept JSON or plain)
    try {
      final resp = await _client.get(
        Uri.parse(_streamDomainEndpoint),
        headers: {'Accept': 'application/json,text/plain,*/*', 'User-Agent': 'Mozilla/5.0'},
      );
      if (resp.statusCode == 200) {
        final raw = resp.body.trim();
        String domain = '';
        try {
          final body = json.decode(raw) as Map<String, dynamic>;
          domain = (body['streamDomain'] as String?)?.trim() ?? '';
        } catch (_) {
          final m = RegExp(r'streamDomain"?\s*[:=]\s*"([^"]+)"').firstMatch(raw) ??
              RegExp(r'"?streamDomain"?\s*[:=]\s*"([^"]+)"').firstMatch(raw);
          if (m != null) domain = m.group(1)!.trim();
        }
        if (domain.isNotEmpty && domain.startsWith('http')) {
          return domain.endsWith('/') ? domain.substring(0, domain.length - 1) : domain;
        }
      }
    } catch (_) {}
    // Fallback to hardcoded known-good
    return 'https://jeyna376dip.com';
  }

  Future<_Metadata> _fetchMetadata({required String playerDomain, required String id}) async {
    final pageUrl = Uri.parse('$playerDomain/play/$id');
    final response = await _client.get(
      pageUrl,
      headers: _browserHeaders(origin: _baseUrl, referer: '$_baseUrl/play/$id'),
    );
    if (response.statusCode != 200) {
      throw MediaError('Media page not found');
    }
    final html = response.body;
    final scriptRegex = RegExp(r'<script[^>]*>([\s\S]*?)<\/script>', multiLine: true);
    final scripts = scriptRegex.allMatches(html).toList();
    if (scripts.isEmpty) {
      throw MediaError('Playback script not found');
    }
    // Iterate from last to first like the JS logic ($('script').last()) but with fallbacks
    String? jsonText;
    final patternA = RegExp(r'(\{[^;]+\});', dotAll: true);
    final patternB = RegExp(r'\((\{[\s\S]*?\})\)', dotAll: true);
    final fallbackAssign = RegExp(r'=\s*(\{[\s\S]*?\});', dotAll: true);
    for (int i = scripts.length - 1; i >= 0 && jsonText == null; i--) {
      final content = scripts[i].group(1) ?? '';
      final mA = patternA.firstMatch(content);
      if (mA != null) {
        jsonText = mA.group(1);
        break;
      }
      final mB = patternB.firstMatch(content);
      if (mB != null) {
        jsonText = mB.group(1);
        break;
      }
      final mC = fallbackAssign.firstMatch(content);
      if (mC != null) {
        jsonText = mC.group(1);
        break;
      }
    }
    if (jsonText == null) {
      throw MediaError('Playback metadata JSON not found');
    }
    Map<String, dynamic> parsed;
    try {
      parsed = json.decode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      // Try to sanitize trailing semicolons or comments
      final cleaned = jsonText.replaceAll(RegExp(r';+$'), '');
      parsed = json.decode(cleaned) as Map<String, dynamic>;
    }
    final file = parsed['file'] as String?;
    final key = parsed['key'] as String?;
    if (file == null || file.isEmpty || key == null || key.isEmpty) {
      throw MediaError('Missing file or key in playback metadata');
    }
    return _Metadata(file: file, key: key, pageUrl: pageUrl.toString());
  }

  Future<MediaInfo> getMediaInfo({required String id}) async {
    if (id.trim().isEmpty) throw MediaError('Missing id');
    final playerDomain = await _discoverPlayerDomain();
    final metadata = await _fetchMetadata(playerDomain: playerDomain, id: id);
    final playlistUrl = metadata.file.startsWith('http')
        ? metadata.file
        : '$playerDomain${metadata.file.startsWith('/') ? '' : '/'}${metadata.file}';

    final response = await _client.get(
      Uri.parse(playlistUrl),
      headers: _browserHeaders(origin: _baseUrl, referer: '$_baseUrl/play/$id', csrf: metadata.key, json: true),
    );
    if (response.statusCode != 200) {
      throw MediaError('Playlist unavailable');
    }
    dynamic playlist;
    try {
      playlist = json.decode(response.body);
    } catch (_) {
      throw MediaError('Invalid playlist format');
    }
    return MediaInfo(playerDomain: playerDomain, key: metadata.key, playlist: playlist, pageUrl: metadata.pageUrl);
  }

  MediaSummary summarize(dynamic playlist) {
    if (playlist is! List) {
      return MediaSummary(type: 'unknown', seasons: []);
    }
    final List seasonsSummary = [];
    final firstTitle = (playlist.isNotEmpty && playlist.first is Map) ? (playlist.first['title']?.toString() ?? '') : '';
    final isTv = firstTitle.toLowerCase().contains('season');
    if (isTv) {
      for (final season in playlist) {
        final folder = (season is Map && season['folder'] is List) ? season['folder'] as List : const [];
        int totalEpisodes = folder.length;
        final Set<String> langs = {};
        for (final ep in folder) {
          if (ep is Map && ep['folder'] is List) {
            for (final lang in ep['folder'] as List) {
              final title = (lang is Map && lang['title'] != null) ? lang['title'].toString() : '';
              if (title.isNotEmpty) langs.add(title);
            }
          }
        }
        seasonsSummary.add({
          'season': season is Map ? (season['title']?.toString() ?? '') : '',
          'totalEpisodes': totalEpisodes,
          'lang': langs.toList(),
        });
      }
      return MediaSummary(type: 'tv', seasons: seasonsSummary);
    } else {
      final Set<String> langs = {};
      for (final item in playlist) {
        if (item is Map && item['title'] != null) {
          final t = item['title'].toString();
          if (t.isNotEmpty) langs.add(t);
        }
      }
      seasonsSummary.add({'lang': langs.toList()});
      return MediaSummary(type: 'movie', seasons: seasonsSummary);
    }
  }

  Future<String> resolveStreamLink({
    required String playerDomain,
    required String key,
    required String file,
    required String referer,
  }) async {
    if (file.isEmpty) throw MediaError('Missing file');
    final normalized = file.startsWith('/') ? file.substring(1) : file;
    final pathTxt = normalized.endsWith('.txt') ? normalized : '$normalized.txt';
    final url = '$playerDomain/playlist/$pathTxt';
    final response = await _client.get(
      Uri.parse(url),
      headers: _browserHeaders(origin: _baseUrl, referer: 'https://google.com/', csrf: key, json: true),
    );
    if (response.statusCode != 200) {
      throw MediaError('No media found');
    }
    final link = response.body.trim();
    if (!link.startsWith('http')) {
      throw MediaError('Invalid stream link');
    }
    return link;
  }
}

class MediaInfo {
  MediaInfo({required this.playerDomain, required this.key, required this.playlist, required this.pageUrl});
  final String playerDomain;
  final String key;
  final dynamic playlist;
  final String pageUrl;
}

class MediaSummary {
  MediaSummary({required this.type, required this.seasons});
  final String type; // 'tv' | 'movie' | 'unknown'
  final List seasons;
}

class _Metadata {
  _Metadata({required this.file, required this.key, required this.pageUrl});
  final String file;
  final String key;
  final String pageUrl;
}

class MediaError implements Exception {
  MediaError(this.message);
  final String message;
  @override
  String toString() => 'MediaError: ' + message;
}


