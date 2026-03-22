class MediaItem {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? releaseDate;
  final List<int> genreIds;
  final String mediaType; // 'movie' or 'tv'
  final String? extraInfo;
  final int? position; // Playback position in ms
  final int? duration; // Total duration in ms

  MediaItem({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    this.releaseDate,
    this.genreIds = const [],
    required this.mediaType,
    this.extraInfo,
    this.position,
    this.duration,
  });

  factory MediaItem.fromMovieJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['original_title'] ?? 'Unknown',
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      releaseDate: json['release_date'],
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      mediaType: 'movie',
    );
  }

  factory MediaItem.fromTvJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] ?? 0,
      title: json['name'] ?? json['original_name'] ?? 'Unknown',
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      releaseDate: json['first_air_date'],
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      mediaType: 'tv',
    );
  }

  factory MediaItem.fromSearchJson(Map<String, dynamic> json) {
    final type = json['media_type'] ?? 'movie';
    if (type == 'tv') return MediaItem.fromTvJson(json);
    return MediaItem.fromMovieJson(json);
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown',
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      releaseDate: json['release_date'],
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      mediaType: json['media_type'] ?? 'movie',
      extraInfo: json['extra_info'],
      position: json['position'],
      duration: json['duration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'vote_average': voteAverage,
      'release_date': releaseDate,
      'genre_ids': genreIds,
      'media_type': mediaType,
      'extra_info': extraInfo,
      'position': position,
      'duration': duration,
    };
  }

  String get fullPosterUrl {
    if (posterPath == null) return '';
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String get fullBackdropUrl {
    if (backdropPath == null) return '';
    return 'https://image.tmdb.org/t/p/w1280$backdropPath';
  }

  String get year {
    if (releaseDate == null || releaseDate!.isEmpty) return '';
    return releaseDate!.split('-').first;
  }

  String get ratingStr => voteAverage.toStringAsFixed(1);

  bool get isUnreleased {
    if (releaseDate == null || releaseDate!.isEmpty) return false;
    try {
      final date = DateTime.parse(releaseDate!);
      return date.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}

class Cast {
  final int id;
  final String name;
  final String? character;
  final String? profilePath;

  Cast({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
  });

  factory Cast.fromJson(Map<String, dynamic> json) {
    return Cast(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      character: json['character'],
      profilePath: json['profile_path'],
    );
  }

  String get fullProfileUrl {
    if (profilePath == null) return '';
    return 'https://image.tmdb.org/t/p/w185$profilePath';
  }
}

class MediaDetail extends MediaItem {
  final List<String> genres;
  final int? runtime;
  final String? tagline;
  final String? status;
  final int? budget;
  final int? revenue;
  final List<String> productionCompanies;
  final List<String> productionCountries;
  final String? homepage;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final List<Cast> cast;
  final List<TvSeason> seasons;

  MediaDetail({
    required super.id,
    required super.title,
    super.overview,
    super.posterPath,
    super.backdropPath,
    required super.voteAverage,
    super.releaseDate,
    super.genreIds,
    super.extraInfo,
    required super.mediaType,
    this.genres = const [],
    this.runtime,
    this.tagline,
    this.status,
    this.budget,
    this.revenue,
    this.productionCompanies = const [],
    this.productionCountries = const [],
    this.homepage,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.cast = const [],
    this.seasons = const [],
  });

  factory MediaDetail.fromMovieDetailJson(Map<String, dynamic> json) {
    return MediaDetail(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['original_title'] ?? 'Unknown',
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      releaseDate: json['release_date'],
      genreIds: [],
      mediaType: 'movie',
      genres:
          (json['genres'] as List?)?.map((g) => g['name'] as String).toList() ??
          [],
      runtime: json['runtime'],
      tagline: json['tagline'],
      status: json['status'],
      budget: json['budget'],
      revenue: json['revenue'],
      productionCompanies:
          (json['production_companies'] as List?)
              ?.map((pc) => pc['name'] as String)
              .toList() ??
          [],
      productionCountries:
          (json['production_countries'] as List?)
              ?.map((pc) => pc['name'] as String)
              .toList() ??
          [],
      homepage: json['homepage'],
      cast:
          (json['credits']?['cast'] as List?)
              ?.map((c) => Cast.fromJson(c))
              .toList() ??
          [],
    );
  }

  factory MediaDetail.fromTvDetailJson(Map<String, dynamic> json) {
    return MediaDetail(
      id: json['id'] ?? 0,
      title: json['name'] ?? json['original_name'] ?? 'Unknown',
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      releaseDate: json['first_air_date'],
      genreIds: [],
      mediaType: 'tv',
      genres:
          (json['genres'] as List?)?.map((g) => g['name'] as String).toList() ??
          [],
      runtime:
          json['episode_run_time'] != null &&
              (json['episode_run_time'] as List).isNotEmpty
          ? (json['episode_run_time'] as List).first
          : null,
      tagline: json['tagline'],
      status: json['status'],
      homepage: json['homepage'],
      productionCompanies:
          (json['production_companies'] as List?)
              ?.map((pc) => pc['name'] as String)
              .toList() ??
          [],
      productionCountries:
          (json['production_countries'] as List?)
              ?.map((pc) => pc['name'] as String)
              .toList() ??
          [],
      numberOfSeasons: json['number_of_seasons'],
      numberOfEpisodes: json['number_of_episodes'],
      cast:
          (json['credits']?['cast'] as List?)
              ?.map((c) => Cast.fromJson(c))
              .toList() ??
          [],
      seasons:
          (json['seasons'] as List?)
              ?.map((s) => TvSeason.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class TvSeason {
  final int id;
  final String name;
  final String? overview;
  final String? posterPath;
  final int seasonNumber;
  final int episodeCount;
  final List<TvEpisode>? episodes;

  TvSeason({
    required this.id,
    required this.name,
    this.overview,
    this.posterPath,
    required this.seasonNumber,
    required this.episodeCount,
    this.episodes,
  });

  factory TvSeason.fromJson(Map<String, dynamic> json) {
    return TvSeason(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      overview: json['overview'],
      posterPath: json['poster_path'],
      seasonNumber: json['season_number'] ?? 0,
      episodeCount: json['episode_count'] ?? 0,
      episodes: (json['episodes'] as List?)
          ?.map((e) => TvEpisode.fromJson(e))
          .toList(),
    );
  }

  String get fullPosterUrl {
    if (posterPath == null) return '';
    return 'https://image.tmdb.org/t/p/w342$posterPath';
  }
}

class TvEpisode {
  final int id;
  final String name;
  final String? overview;
  final String? stillPath;
  final int episodeNumber;
  final int seasonNumber;
  final double voteAverage;
  final DateTime? airDate;

  TvEpisode({
    required this.id,
    required this.name,
    this.overview,
    this.stillPath,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.voteAverage,
    this.airDate,
  });

  factory TvEpisode.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['air_date'] != null && json['air_date'].toString().isNotEmpty) {
      parsedDate = DateTime.tryParse(json['air_date']);
    }

    return TvEpisode(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      overview: json['overview'],
      stillPath: json['still_path'],
      episodeNumber: json['episode_number'] ?? 0,
      seasonNumber: json['season_number'] ?? 0,
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      airDate: parsedDate,
    );
  }

  String get fullStillUrl {
    if (stillPath == null) return '';
    return 'https://image.tmdb.org/t/p/w300$stillPath';
  }
}
