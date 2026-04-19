import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/game.dart';
import '../models/api_models.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── APP CONFIG ──────────────────────────────────────────────────────────
  static const String appVersion = 'v2.1';
  static const String websiteUrl = 'https://driishya.vercel.app';

  // ── LOGGING ─────────────────────────────────────────────────────────────
  void _logReq(String url) => debugPrint('🚀 [API REQ] $url');
  void _logRes(String url, int code) =>
      debugPrint('${code == 200 ? '✅' : '❌'} [API RES] $code: $url');
  void _logErr(String url, dynamic e) => debugPrint('💥 [API ERR] $e: $url');

  // ── DYNAMIC BASE URL ────────────────────────────────────────────────────
  String _apiBase = ''; // Loaded from SharedPreferences

  String get _tmdbBase => '$_apiBase/tmdb';
  String get _gamesUrl => '$_apiBase/games';
  String get streamingBase => '$_apiBase/media';
  String get downloadBase => '$_apiBase/download';

  // IPTV base - now empty by default
  static const String _iptvBase = 'https://iptvwrapper.antig9469.workers.dev';

  // ── UPDATE CONFIG ────────────────────────────────────────────────────────
  static const String _repoOwner = 'Shashwat-CODING';
  static const String _repoName = 'Drishya';
  static const String _updateUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBase = prefs.getString('api_base_url') ?? '';
  }

  Future<bool> validateBaseUrl(String url) async {
    try {
      // 1. Clean up the URL (trim whitespace and trailing quotes/junk)
      String formatted = url.trim().replaceAll(RegExp(r'''['" \s]+$'''), '');
      if (formatted.endsWith('/')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }

      // 2. Try health check at root /health first
      if (await _checkHealth('$formatted/health')) return true;

      // 3. Try health check at /api/health
      if (await _checkHealth('$formatted/api/health')) return true;

      return false;
    } catch (e) {
      _logErr(url, e);
      return false;
    }
  }

  Future<bool> _checkHealth(String url) async {
    try {
      final uri = Uri.parse(url);
      _logReq(uri.toString());
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);

      if (res.statusCode == 200) {
        final body = res.body.trim().toLowerCase();
        return body == 'ok';
      }
    } catch (_) {}
    return false;
  }

  Future<void> setBaseUrl(String url) async {
    String formatted = url.trim().replaceAll(RegExp(r'''['" \s]+$'''), '');
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    // If user provided root but not /api, add it
    if (!formatted.contains('/api')) {
      formatted = '$formatted/api';
    }

    _apiBase = formatted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', formatted);
  }

  bool get isConfigured => _apiBase.isNotEmpty;

  // ── TMDB METHODS ─────────────────────────────────────────────────────────

  Future<List<MediaItem>> _fetchTmdbMovies(
    String endpoint, {
    Map<String, String>? extra,
  }) async {
    if (!isConfigured) return [];
    final uri = Uri.parse(
      '$_tmdbBase$endpoint',
    ).replace(queryParameters: extra);
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results
            .map((j) => MediaItem.fromMovieJson(j))
            .where((m) => m.posterPath != null)
            .toList();
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return [];
  }

  Future<List<MediaItem>> _fetchTmdbTv(
    String endpoint, {
    Map<String, String>? extra,
  }) async {
    if (!isConfigured) return [];
    final uri = Uri.parse(
      '$_tmdbBase$endpoint',
    ).replace(queryParameters: extra);
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results
            .map((j) => MediaItem.fromTvJson(j))
            .where((m) => m.posterPath != null)
            .toList();
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return [];
  }

  Future<List<MediaItem>> getTrendingMovies() =>
      _fetchTmdbMovies('/trending/movie/week');
  Future<List<MediaItem>> getPopularMovies() =>
      _fetchTmdbMovies('/movie/popular');
  Future<List<MediaItem>> getTopRatedMovies() =>
      _fetchTmdbMovies('/movie/top_rated');
  Future<List<MediaItem>> getUpcomingMovies() =>
      _fetchTmdbMovies('/movie/upcoming');
  Future<List<MediaItem>> getNowPlayingMovies() =>
      _fetchTmdbMovies('/movie/now_playing');

  Future<List<MediaItem>> getPopularTvShows() => _fetchTmdbTv('/tv/popular');
  Future<List<MediaItem>> getTopRatedTvShows() => _fetchTmdbTv('/tv/top_rated');
  Future<List<MediaItem>> getTrendingTv() => _fetchTmdbTv('/trending/tv/week');
  Future<List<MediaItem>> getAiringTodayTv() =>
      _fetchTmdbTv('/tv/airing_today');

  Future<List<MediaItem>> getAnimeMovies() => _fetchTmdbMovies(
    '/discover/movie',
    extra: {'with_genres': '16', 'sort_by': 'popularity.desc'},
  );
  Future<List<MediaItem>> getAnimeTv() => _fetchTmdbTv(
    '/discover/tv',
    extra: {'with_genres': '16', 'sort_by': 'popularity.desc'},
  );

  Future<List<MediaItem>> search(String query) async {
    if (!isConfigured || query.trim().isEmpty) return [];
    final uri = Uri.parse(
      '$_tmdbBase/search/multi',
    ).replace(queryParameters: {'query': query});
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results
            .where((j) => j['media_type'] != 'person')
            .map((j) => MediaItem.fromSearchJson(j))
            .where((m) => m.posterPath != null)
            .toList();
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return [];
  }

  Future<MediaDetail?> getMovieDetail(int id) async {
    if (!isConfigured) return null;
    final uri = Uri.parse(
      '$_tmdbBase/movie/$id',
    ).replace(queryParameters: {'append_to_response': 'credits'});
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        return MediaDetail.fromMovieDetailJson(jsonDecode(res.body));
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return null;
  }

  Future<MediaDetail?> getTvDetail(int id) async {
    if (!isConfigured) return null;
    final uri = Uri.parse(
      '$_tmdbBase/tv/$id',
    ).replace(queryParameters: {'append_to_response': 'credits'});
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        return MediaDetail.fromTvDetailJson(jsonDecode(res.body));
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return null;
  }

  Future<TvSeason?> getTvSeasonDetail(int tvId, int seasonNumber) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_tmdbBase/tv/$tvId/season/$seasonNumber');
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        return TvSeason.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return null;
  }

  Future<TvEpisode?> getTvEpisodeDetail(
    int tvId,
    int season,
    int episode,
  ) async {
    if (!isConfigured) return null;
    final uri = Uri.parse(
      '$_tmdbBase/tv/$tvId/season/$season/episode/$episode',
    );
    _logReq(uri.toString());
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _logRes(uri.toString(), res.statusCode);
      if (res.statusCode == 200) {
        return TvEpisode.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      _logErr(uri.toString(), e);
    }
    return null;
  }

  Future<List<MediaItem>> getSimilarMovies(int id) =>
      _fetchTmdbMovies('/movie/$id/similar');
  Future<List<MediaItem>> getSimilarTv(int id) =>
      _fetchTmdbTv('/tv/$id/similar');

  // ── IPTV METHODS ──────────────────────────────────────────────────────────

  Future<List<CountryEntry>> fetchCountries() async {
    final url = '$_iptvBase/countries';
    _logReq(url);
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => CountryEntry.fromJson(item)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<RegionEntry>> fetchRegions() async {
    final url = '$_iptvBase/regions';
    _logReq(url);
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => RegionEntry.fromJson(item)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<CategoryEntry>> fetchCategories() async {
    final url = '$_iptvBase/categories';
    _logReq(url);
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => CategoryEntry.fromJson(item)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<List<LanguageEntry>> fetchLanguages() async {
    final url = '$_iptvBase/languages';
    _logReq(url);
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => LanguageEntry.fromJson(item)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      _logErr(url, e);
    }
    return [];
  }

  Future<IptvResponse> fetchChannelsByCountry(
    String code, {
    int page = 1,
    int perPage = 100,
  }) async {
    final url = '$_iptvBase/country/$code?page=$page&per_page=$perPage';
    _logReq(url);
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200)
        return IptvResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      _logErr(url, e);
    }
    return IptvResponse.empty();
  }

  Future<IptvResponse> fetchChannelsByRegion(
    String code, {
    int page = 1,
    int perPage = 100,
  }) async {
    final url = '$_iptvBase/region/$code?page=$page&per_page=$perPage';
    _logReq(url);
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200)
        return IptvResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      _logErr(url, e);
    }
    return IptvResponse.empty();
  }

  Future<IptvResponse> searchChannels(
    String query, {
    String? country,
    String? category,
    int page = 1,
    int perPage = 100,
  }) async {
    try {
      var url = '$_iptvBase/search?q=$query&page=$page&per_page=$perPage';
      if (country != null) url += '&country=$country';
      if (category != null) url += '&category=$category';
      _logReq(url);
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      _logRes(url, res.statusCode);
      if (res.statusCode == 200)
        return IptvResponse.fromJson(jsonDecode(res.body));
    } catch (e) {
      _logErr(query, e);
    }
    return IptvResponse.empty();
  }

  // ── UPDATE METHODS ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> checkForUpdate() async {
    _logReq(_updateUrl);
    try {
      final response = await http.get(Uri.parse(_updateUrl));
      _logRes(_updateUrl, response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestTag = data['tag_name'] as String;
        final latest = latestTag.startsWith('v')
            ? latestTag.substring(1)
            : latestTag;
        final current = appVersion.startsWith('v')
            ? appVersion.substring(1)
            : appVersion;
        if (_isNewer(latest, current)) {
          return {
            'version': latestTag,
            'changelog': data['body'],
            'url': '$websiteUrl/#download',
          };
        }
      }
    } catch (e) {
      _logErr(_updateUrl, e);
    }
    return null;
  }

  bool _isNewer(String latest, String current) {
    List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < l.length && i < c.length; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return l.length > c.length;
  }

  // ── GAMES METHODS ────────────────────────────────────────────────────────

  Future<List<Game>> fetchGames() async {
    if (!isConfigured) return [];
    _logReq(_gamesUrl);
    try {
      final res = await http.get(Uri.parse(_gamesUrl));
      _logRes(_gamesUrl, res.statusCode);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((j) => Game.fromJson(j)).toList();
      }
    } catch (e) {
      _logErr(_gamesUrl, e);
    }
    return [];
  }
}
