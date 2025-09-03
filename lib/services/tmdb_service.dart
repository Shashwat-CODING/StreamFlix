import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  TmdbService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiKey = 'ccea33eff57085a37240864ea9a27b4a';
  static const String _readAccessToken = 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJjY2VhMzNlZmY1NzA4NWEzNzI0MDg2NGVhOWEyN2I0YSIsIm5iZiI6MTc0MTc4MDAwNy4zNzIsInN1YiI6IjY3ZDE3NDI3NDM0Yzk4YzhlYzgxNjkxZiIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.0cbFGi6YMvbfz9rNMzhB5CBYctd-_sv6vzd5nOYBUBM';
  static const String _baseUrl = 'https://tmdbproxy.bob17040246.workers.dev/3';
  static const String imageBase = 'https://image.tmdb.org/t/p/w342';

  Map<String, String> _headers() => {
        'Authorization': 'Bearer ' + _readAccessToken,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<TmdbSearchResult> searchMultiPaged(String query, {int page = 1}) async {
    final uri = Uri.parse(_baseUrl + '/search/multi').replace(queryParameters: {
      'query': query,
      'include_adult': 'false',
      'language': 'en-US',
      'page': page.toString(),
    });
    final resp = await _client.get(uri, headers: _headers());
    if (resp.statusCode != 200) {
      return TmdbSearchResult(items: const [], page: page, totalPages: 1);
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];
    final items = results.map((e) => TmdbItem.fromJson(e as Map<String, dynamic>)).where((e) => e.id != null).toList();
    final currentPage = (data['page'] is int) ? data['page'] as int : int.tryParse((data['page'] ?? '1').toString()) ?? page;
    final totalPages = (data['total_pages'] is int)
        ? data['total_pages'] as int
        : int.tryParse((data['total_pages'] ?? '1').toString()) ?? 1;
    return TmdbSearchResult(items: items, page: currentPage, totalPages: totalPages);
  }

  Future<List<TmdbItem>> popularMovies() async {
    try {
      final uri = Uri.parse(_baseUrl + '/movie/popular').replace(queryParameters: {
        'language': 'en-US',
        'page': '1',
      });
      final resp = await _client.get(uri, headers: _headers());
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final results = (data['results'] as List?) ?? [];
        final list = results
            .map((e) => TmdbItem.fromJson({...e as Map<String, dynamic>, 'media_type': 'movie'}))
            .where((e) => e.id != null)
            .toList();
        if (list.isNotEmpty) return list;
      }
      // fallthrough to fallback
    } catch (_) {}
    try {
      // Fallback to curated JSON similar to HTML reference
      final alt = await _client.get(
        Uri.parse('https://raw.githubusercontent.com/Shashwat-CODING/redirect/refs/heads/main/player.json'),
      );
      if (alt.statusCode != 200) return [];
      final data = json.decode(alt.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? [];
      return results
          .map((e) => TmdbItem.fromJson({...e as Map<String, dynamic>, 'media_type': 'movie'}))
          .where((e) => e.id != null)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> getImdbId({required String mediaType, required int tmdbId}) async {
    // Use details with append_to_response like the HTML reference, no api_key in query
    final endpoint = mediaType == 'movie' ? 'movie' : 'tv';
    final uri = Uri.parse(_baseUrl + '/$endpoint/$tmdbId').replace(queryParameters: {
      'append_to_response': 'external_ids',
    });
    final resp = await _client.get(uri, headers: _headers());
    if (resp.statusCode != 200) return null;
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final imdb = (data['external_ids']?['imdb_id'] ?? data['imdb_id'])?.toString();
    if (imdb == null || imdb.isEmpty || imdb == 'null') return null;
    return imdb;
  }

  Future<Map<String, dynamic>?> details({required String mediaType, required int tmdbId}) async {
    final endpoint = mediaType == 'movie' ? 'movie' : 'tv';
    final uri = Uri.parse(_baseUrl + '/$endpoint/$tmdbId').replace(queryParameters: {
      'append_to_response': 'external_ids,credits,release_dates,content_ratings',
      'language': 'en-US',
    });
    final resp = await _client.get(uri, headers: _headers());
    if (resp.statusCode != 200) return null;
    try {
      return json.decode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

class TmdbItem {
  TmdbItem({this.id, required this.mediaType, required this.title, this.posterPath});
  final int? id;
  final String mediaType; // movie | tv | person
  final String title;
  final String? posterPath;

  String? get posterUrl => posterPath == null ? null : (TmdbService.imageBase + posterPath!);

  factory TmdbItem.fromJson(Map<String, dynamic> json) {
    final mediaType = (json['media_type']?.toString() ?? 'movie');
    final title = (json['title'] ?? json['name'] ?? '').toString();
    return TmdbItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse((json['id'] ?? '').toString()),
      mediaType: mediaType,
      title: title,
      posterPath: (json['poster_path'] ?? json['profile_path'])?.toString(),
    );
  }
}

class TmdbSearchResult {
  TmdbSearchResult({required this.items, required this.page, required this.totalPages});
  final List<TmdbItem> items;
  final int page;
  final int totalPages;
}


