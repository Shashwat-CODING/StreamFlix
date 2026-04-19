import '../models/channel.dart';

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
  final int serverId;
  final String? referer;
  final String? origin;
  final String? size;
  final List<Subtitle>? subtitles;
  final Map<String, String>? headers;
  final int priority;

  /// When true, the player must send NO headers at all for this source.
  final bool noHeaders;
  final int fileSize;
  final String? sizeText; // Human-readable size (e.g. "25.30 GB")
  final String? type;     // Content type (e.g. "mp4", "m3u8")
  final String? language;

  static const String kDefaultReferer = 'https://rivestream.app/';
  static const String kDefaultOrigin = 'https://rivestream.app';

  String get resolvedReferer =>
      (referer != null && referer!.isNotEmpty) ? referer! : kDefaultReferer;
  String get resolvedOrigin =>
      (origin != null && origin!.isNotEmpty) ? origin! : kDefaultOrigin;

  StreamSource({
    required this.quality,
    required this.url,
    required this.source,
    required this.serverId,
    this.referer,
    this.origin,
    this.size,
    this.subtitles,
    this.headers,
    this.priority = 10,
    this.noHeaders = false,
    this.fileSize = 0,
    this.sizeText,
    this.type,
    this.language,
  });

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    var rawQuality = json['quality'];
    String q = 'Auto';
    if (rawQuality is num) {
      q = '${rawQuality}p';
    } else if (rawQuality != null) {
      q = rawQuality.toString();
      if (!q.contains('p') && int.tryParse(q) != null) q = '${q}p';
    }

    final String metadata = (json['metadata'] ?? json['server'] ?? json['provider'] ?? 'Unknown').toString();
    
    // Extract language from various potential fields
    String? language = (json['lang'] ?? json['language'])?.toString();
    
    // Handle the new Language:Type format (e.g., "Hindi:dubbed", "Arabic:subtitle")
    if (language != null && language.contains(':')) {
      final parts = language.split(':');
      if (parts.length == 2) {
        String langName = parts[0].trim();
        String typeLabel = parts[1].trim().toLowerCase();
        
        // Capitalize language name (e.g. ptbr -> Ptbr)
        if (langName.isNotEmpty) {
          langName = langName[0].toUpperCase() + langName.substring(1);
        }

        if (typeLabel == 'dubbed' || typeLabel == 'dub') {
           language = '$langName Dubbed';
        } else if (typeLabel == 'subtitle' || typeLabel == 'sub') {
           language = '$langName Subbed';
        } else if (typeLabel == 'audio') {
           language = langName; // Original:audio -> Original
        } else {
           language = '$langName ${typeLabel[0].toUpperCase()}${typeLabel.substring(1)}';
        }
      }
    }

    // Handle the 'type' field as requested: sun -> Subtitles, dub -> Dubbed
    final String? typeField = json['type']?.toString().toLowerCase();
    if (language == null || language.toLowerCase() == 'unknown') {
      if (typeField == 'sun' || typeField == 'sub') {
        language = 'Subbed';
      } else if (typeField == 'dub') {
        language = 'Dubbed';
      }
    }

    if (language == null || language.isEmpty || language.toLowerCase() == 'unknown') {
      final metaMatch = RegExp(r'\((.*?)\)', caseSensitive: false).firstMatch(metadata);
      if (metaMatch != null) {
        final String content = metaMatch.group(1)!;
        final String lowerContent = content.toLowerCase();

        if (lowerContent.contains('dub')) {
          String langName = content.replaceAll(RegExp(r'dub', caseSensitive: false), '').trim();
          language = langName.isEmpty ? 'Dubbed' : '$langName Dubbed';
        } else if (lowerContent.contains('sub') || lowerContent.contains('sun')) {
          String langName = content.replaceAll(RegExp(r'sub|sun', caseSensitive: false), '').trim();
          language = langName.isEmpty ? 'Subbed' : '$langName Subbed';
        } else if (lowerContent.contains('original') || lowerContent.contains('audio')) {
          language = 'Original';
        } else {
          language = content; // Fallback to content inside parentheses
        }
      } else {
        // Fallback checks for keywords outside of parentheses
        final String lowerMeta = metadata.toLowerCase();
        if (lowerMeta.contains('sun') || lowerMeta.contains('sub')) {
          language = 'Subbed';
        } else if (lowerMeta.contains('dub')) {
          language = 'Dubbed';
        }
      }
    }

    // Final fallback: if it's from server 2 and still unknown, check if the URL contains clues
    if ((language == null || language.toLowerCase() == 'unknown') && json['serverId'] == 2) {
       final url = json['url']?.toString().toLowerCase() ?? '';
       if (url.contains('dub')) language = 'Dubbed';
       else if (url.contains('sub')) language = 'Subbed';
    }

    return StreamSource(
      quality: q,
      url: json['url']?.toString() ?? '',
      source: metadata,
      serverId: json['serverId'] ?? 0,
      referer: json['referer']?.toString(),
      origin: json['origin']?.toString(),
      size: json['size']?.toString(),
      sizeText: json['sizeText']?.toString(),
      type: typeField,
      headers: (json['headers'] as Map?)?.cast<String, String>(),
      language: language,
    );
  }
  @override
  String toString() => '[$serverId] $source ($quality) ${language != null ? "[$language]" : ""} - $url';
}

class IptvResponse {
  final int page;
  final int count;
  final int totalPages;
  final List<Channel> results;

  IptvResponse({
    required this.page,
    required this.count,
    required this.totalPages,
    required this.results,
  });

  factory IptvResponse.fromJson(Map<String, dynamic> json) {
    return IptvResponse(
      page: json['page'] ?? 1,
      count: json['count'] ?? 0,
      totalPages: json['total_pages'] ?? 1,
      results:
          (json['results'] as List?)
               ?.map((c) => Channel.fromJson(c))
               .toList() ??
          [],
    );
  }

  factory IptvResponse.empty() =>
      IptvResponse(page: 1, count: 0, totalPages: 1, results: []);
}

class CountryEntry {
  final String code;
  final String name;
  final String flag;
  final List<String> languages;
  const CountryEntry({
    required this.code,
    required this.name,
    required this.flag,
    required this.languages,
  });

  factory CountryEntry.fromJson(Map<String, dynamic> json) => CountryEntry(
    code: json['code']?.toString().toLowerCase() ?? '',
    name: json['name'] ?? '',
    flag: json['flag'] ?? '',
    languages: List<String>.from(json['languages'] ?? []),
  );
}

class RegionEntry {
  final String code;
  final String name;
  final List<String> countries;
  const RegionEntry({
    required this.code,
    required this.name,
    required this.countries,
  });

  factory RegionEntry.fromJson(Map<String, dynamic> json) => RegionEntry(
    code: json['code'] ?? '',
    name: json['name'] ?? '',
    countries: List<String>.from(json['countries'] ?? []),
  );
}

class CategoryEntry {
  final String id;
  final String name;
  const CategoryEntry({required this.id, required this.name});

  factory CategoryEntry.fromJson(Map<String, dynamic> json) =>
      CategoryEntry(id: json['id'] ?? '', name: json['name'] ?? '');
}

class LanguageEntry {
  final String code;
  final String name;
  const LanguageEntry({required this.code, required this.name});

  factory LanguageEntry.fromJson(Map<String, dynamic> json) =>
      LanguageEntry(code: json['code'] ?? '', name: json['name'] ?? '');
}
