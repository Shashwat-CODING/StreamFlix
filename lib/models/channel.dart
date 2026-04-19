class Channel {
  final String id;
  final String name;
  final String? logoUrl;
  final String? group;
  final String? country;
  final bool isNsfw;
  final List<VideoStream> streams;

  Channel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.group,
    this.country,
    this.isNsfw = false,
    required this.streams,
  });

  String get displayName => name;
  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;
  String? get tvgId => id;

  // Use the first stream as default for legacy compatibility if needed
  String get streamUrl => streams.isNotEmpty ? streams.first.url : '';
  String? get referrer => streams.isNotEmpty ? streams.first.referrer : null;
  String? get userAgent => streams.isNotEmpty ? streams.first.userAgent : null;

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      logoUrl: json['logo'],
      group: (json['categories'] as List?)?.firstOrNull?.toString(),
      country: json['country'],
      isNsfw: json['is_nsfw'] ?? false,
      streams:
          (json['streams'] as List?)
              ?.map((s) => VideoStream.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class VideoStream {
  final String url;
  final String? quality;
  final String? title;
  final String? referrer;
  final String? userAgent;
  final Map<String, String>? headers;

  VideoStream({
    required this.url,
    this.quality,
    this.title,
    this.referrer,
    this.userAgent,
    this.headers,
  });

  factory VideoStream.fromJson(Map<String, dynamic> json) {
    return VideoStream(
      url: json['url'] ?? '',
      quality: json['quality'],
      title: json['title'],
      referrer: json['referrer'],
      userAgent: json['user_agent'],
      headers: (json['headers'] as Map?)?.cast<String, String>(),
    );
  }
}
