import 'package:http/http.dart' as http;
import '../player/stream_resolution.dart';
import 'dart:convert';

class VidsrcServerResolver {
  static const String _ua = 'Mozilla/5.0 (Linux; Android 12; Flutter) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  String buildEmbedUrl({required int tmdbId, required String mediaType}) {
    final typePath = (mediaType == 'tv') ? 'tv' : 'movie';
    return 'https://vidsrc.cc/v2/embed/' + typePath + '/' + tmdbId.toString() + '?autoPlay=true';
  }

  Future<ResolvedStream> resolveViaHtml({required String embedUrl}) async {
    final resp = await http.get(Uri.parse(embedUrl), headers: const {
      'User-Agent': _ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    });
    if (resp.statusCode != 200) throw Exception('Vidsrc HTML fetch failed');
    final html = resp.body;
    final regex = RegExp(r'https://[^"\s]+\.m3u8[^"\s]*');
    final m = regex.firstMatch(html);
    if (m == null) throw Exception('Vidsrc m3u8 not found');
    final hlsUrl = m.group(0)!;
    final headers = <String, String>{
      'User-Agent': _ua,
      'Accept': '*/*',
      'Origin': 'https://vidsrc.cc',
      'Referer': embedUrl,
      'Connection': 'keep-alive',
    };
    return ResolvedStream(hlsUrl: hlsUrl, headers: headers);
  }

  Future<ResolvedStream> resolveViaApi({required int tmdbId, required String mediaType}) async {
    final embedUrl = buildEmbedUrl(tmdbId: tmdbId, mediaType: mediaType);
    // 1) Load embed HTML to extract variables
    final htmlResp = await http.get(Uri.parse(embedUrl), headers: const {
      'User-Agent': _ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    });
    if (htmlResp.statusCode != 200) {
      throw Exception('Vidsrc embed fetch failed');
    }
    final html = htmlResp.body;
    String? v = _extractVar(html, 'v') ?? _extractJsonLike(html, 'v');
    String? movieId = _extractVar(html, 'movieId') ?? _extractJsonLike(html, 'movieId');
    String? imdbId = _extractVar(html, 'imdbId') ?? _extractJsonLike(html, 'imdbId');
    String? movieType = _extractVar(html, 'movieType') ?? _extractJsonLike(html, 'movieType');
    String? vrf = _extractVar(html, 'vrf') ?? _extractJsonLike(html, 'vrf');
    if (movieId == null || movieType == null || v == null) {
      // As a fallback, use known values from parameters
      movieId = tmdbId.toString();
      movieType = mediaType;
      v = v ?? '1';
    }

    // 2) Servers list (attempt with vrf, then without)
    Future<http.Response> _fetchServers({bool includeVrf = true}) {
      final qp = <String, String>{
        'id': movieId!,
        'type': movieType!,
        'v': v!,
        if (includeVrf && vrf != null && vrf!.isNotEmpty) 'vrf': vrf!,
        if (imdbId != null && imdbId!.isNotEmpty && imdbId != 'null') 'imdbId': imdbId!,
      };
      final serversUri = Uri.parse('https://vidsrc.cc/api/' + Uri.encodeComponent(movieId!) + '/servers').replace(queryParameters: qp);
      return http.get(serversUri, headers: {
        'User-Agent': _ua,
        'Accept': 'application/json, text/plain, */*',
        'Referer': embedUrl,
        'Origin': 'https://vidsrc.cc',
        'Connection': 'keep-alive',
        'X-Requested-With': 'XMLHttpRequest',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
      });
    }

    http.Response serversResp = await _fetchServers(includeVrf: true);
    if (serversResp.statusCode != 200) {
      serversResp = await _fetchServers(includeVrf: false);
    }
    if (serversResp.statusCode != 200) {
      throw Exception('Vidsrc servers API failed');
    }
    final serversJson = json.decode(serversResp.body) as Map<String, dynamic>;
    final data = (serversJson['data'] as List?) ?? const [];
    if (data.isEmpty) throw Exception('No servers returned');
    String? vidplayHash;
    for (final s in data) {
      final m = s as Map<String, dynamic>;
      if ((m['name'] ?? '').toString().toLowerCase() == 'vidplay') {
        vidplayHash = (m['hash'] ?? '').toString();
        break;
      }
    }
    vidplayHash ??= ((data.first as Map<String, dynamic>)['hash'] ?? '').toString();
    if (vidplayHash.isEmpty) throw Exception('Missing server hash');

    // 3) Source by hash
    final sourceUri = Uri.parse('https://vidsrc.cc/api/source/' + Uri.encodeComponent(vidplayHash));
    final sourceResp = await http.get(sourceUri, headers: {
      'User-Agent': _ua,
      'Accept': 'application/json, text/plain, */*',
      'Referer': embedUrl,
      'Origin': 'https://vidsrc.cc',
      'Connection': 'keep-alive',
      'X-Requested-With': 'XMLHttpRequest',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
    });
    if (sourceResp.statusCode != 200) {
      throw Exception('Vidsrc source API failed');
    }
    final sourceJson = json.decode(sourceResp.body) as Map<String, dynamic>;
    final src = ((sourceJson['data'] as Map<String, dynamic>?) ?? const {})['source']?.toString() ?? '';
    if (src.isEmpty) throw Exception('Vidsrc source missing');
    final headers = <String, String>{
      'User-Agent': _ua,
      'Accept': '*/*',
      'Origin': 'https://vidsrc.cc',
      'Referer': embedUrl,
      'Connection': 'keep-alive',
    };
    return ResolvedStream(hlsUrl: src, headers: headers);
  }

  String? _extractVar(String html, String name) {
    final re1 = RegExp('var\\s+' + RegExp.escape(name) + '\\s*=\\s*"([^"]*)"');
    final re2 = RegExp("var\\s+" + RegExp.escape(name) + "\\s*=\\s*'([^']*)'");
    final re3 = RegExp(RegExp.escape(name) + '\\s*=\\s*"([^"]*)"');
    final re4 = RegExp(RegExp.escape(name) + "\\s*=\\s*'([^']*)'");
    for (final re in [re1, re2, re3, re4]) {
      final m = re.firstMatch(html);
      if (m != null) return m.group(1);
    }
    return null;
  }

  String? _extractJsonLike(String html, String name) {
    // Covers patterns like: "name":"value" or 'name':'value'
    final re1 = RegExp('"' + RegExp.escape(name) + '"\s*:\s*"([^"]*)"');
    final re2 = RegExp("'" + RegExp.escape(name) + "'\s*:\s*'([^']*)'");
    final m1 = re1.firstMatch(html);
    if (m1 != null) return m1.group(1);
    final m2 = re2.firstMatch(html);
    if (m2 != null) return m2.group(1);
    return null;
  }

  // WebView hook removed; resolution is now HTML/API based using web_scraper and HTTP
}


