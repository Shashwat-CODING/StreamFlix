import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../theme/constants.dart';

class TmdbService {
  static const String _base = AppConstants.tmdbBaseUrl;
  static const String _key = AppConstants.tmdbApiKey;

  Future<List<MediaItem>> _fetchMovies(
    String endpoint, {
    Map<String, String>? extra,
  }) async {
    final params = {'api_key': _key, ...?extra};
    final uri = Uri.parse('$_base$endpoint').replace(queryParameters: params);
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results
            .map((j) => MediaItem.fromMovieJson(j))
            .where((m) => m.posterPath != null)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<MediaItem>> _fetchTv(
    String endpoint, {
    Map<String, String>? extra,
  }) async {
    final params = {'api_key': _key, ...?extra};
    final uri = Uri.parse('$_base$endpoint').replace(queryParameters: params);
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results
            .map((j) => MediaItem.fromTvJson(j))
            .where((m) => m.posterPath != null)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // Movies
  Future<List<MediaItem>> getTrendingMovies() =>
      _fetchMovies('/trending/movie/week');

  Future<List<MediaItem>> getPopularMovies() => _fetchMovies('/movie/popular');

  Future<List<MediaItem>> getTopRatedMovies() =>
      _fetchMovies('/movie/top_rated');

  Future<List<MediaItem>> getUpcomingMovies() =>
      _fetchMovies('/movie/upcoming');

  Future<List<MediaItem>> getNowPlayingMovies() =>
      _fetchMovies('/movie/now_playing');

  // TV Shows
  Future<List<MediaItem>> getPopularTvShows() => _fetchTv('/tv/popular');

  Future<List<MediaItem>> getTopRatedTvShows() => _fetchTv('/tv/top_rated');

  Future<List<MediaItem>> getTrendingTv() => _fetchTv('/trending/tv/week');

  Future<List<MediaItem>> getAiringTodayTv() => _fetchTv('/tv/airing_today');

  // Anime (animation genre = 16)
  Future<List<MediaItem>> getAnimeMovies() => _fetchMovies(
    '/discover/movie',
    extra: {'with_genres': '16', 'sort_by': 'popularity.desc'},
  );

  Future<List<MediaItem>> getAnimeTv() => _fetchTv(
    '/discover/tv',
    extra: {'with_genres': '16', 'sort_by': 'popularity.desc'},
  );

  Future<List<MediaItem>> getTrendingAnime() => _fetchTv('/trending/tv/week');

  // Search
  Future<List<MediaItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse(
      '$_base/search/multi',
    ).replace(queryParameters: {'api_key': _key, 'query': query});
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results
            .where((j) => j['media_type'] != 'person')
            .map((j) => MediaItem.fromSearchJson(j))
            .where((m) => m.posterPath != null)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // Detail
  Future<MediaDetail?> getMovieDetail(int id) async {
    final uri = Uri.parse('$_base/movie/$id').replace(
      queryParameters: {'api_key': _key, 'append_to_response': 'credits'},
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return MediaDetail.fromMovieDetailJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  Future<MediaDetail?> getTvDetail(int id) async {
    final uri = Uri.parse('$_base/tv/$id').replace(
      queryParameters: {'api_key': _key, 'append_to_response': 'credits'},
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return MediaDetail.fromTvDetailJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  Future<TvSeason?> getTvSeasonDetail(int tvId, int seasonNumber) async {
    final uri = Uri.parse(
      '$_base/tv/$tvId/season/$seasonNumber',
    ).replace(queryParameters: {'api_key': _key});
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return TvSeason.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  Future<TvEpisode?> getTvEpisodeDetail(
    int tvId,
    int season,
    int episode,
  ) async {
    final uri = Uri.parse(
      '$_base/tv/$tvId/season/$season/episode/$episode',
    ).replace(queryParameters: {'api_key': _key});
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return TvEpisode.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }
}
