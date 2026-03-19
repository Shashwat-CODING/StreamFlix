import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class IptvService {
  static const String _apiBase = 'https://iptvwrapper.antig9469.workers.dev';

  // ─── Countries ───────────────────────────────────────────────────────────

  Future<List<CountryEntry>> fetchCountries() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBase/countries'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((item) => CountryEntry.fromJson(item)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      debugPrint('fetchCountries Error: $e');
    }
    return [];
  }

  // ─── Regions ─────────────────────────────────────────────────────────────

  Future<List<RegionEntry>> fetchRegions() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBase/regions'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((item) => RegionEntry.fromJson(item)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      debugPrint('fetchRegions Error: $e');
    }
    return [];
  }

  // ─── Categories ──────────────────────────────────────────────────────────

  Future<List<CategoryEntry>> fetchCategories() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBase/categories'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((item) => CategoryEntry.fromJson(item)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      debugPrint('fetchCategories Error: $e');
    }
    return [];
  }

  // ─── Languages ───────────────────────────────────────────────────────────

  Future<List<LanguageEntry>> fetchLanguages() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBase/languages'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((item) => LanguageEntry.fromJson(item)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      debugPrint('fetchLanguages Error: $e');
    }
    return [];
  }

  // ─── Channels & Streams ──────────────────────────────────────────────────

  Future<IptvResponse> fetchChannelsByCountry(
    String countryCode, {
    int page = 1,
    int perPage = 100,
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse(
              '$_apiBase/country/$countryCode?page=$page&per_page=$perPage',
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        return IptvResponse.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('fetchChannelsByCountry Error: $e');
    }
    return IptvResponse.empty();
  }

  Future<IptvResponse> fetchChannelsByRegion(
    String regionCode, {
    int page = 1,
    int perPage = 100,
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse(
              '$_apiBase/region/$regionCode?page=$page&per_page=$perPage',
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        return IptvResponse.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('fetchChannelsByRegion Error: $e');
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
      var url = '$_apiBase/search?q=$query&page=$page&per_page=$perPage';
      if (country != null) url += '&country=$country';
      if (category != null) url += '&category=$category';

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        return IptvResponse.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('searchChannels Error: $e');
    }
    return IptvResponse.empty();
  }
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
