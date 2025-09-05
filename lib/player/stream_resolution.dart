import 'package:flutter/foundation.dart';

class ResolvedStream {
  ResolvedStream({required this.hlsUrl, required this.headers});
  final String hlsUrl;
  final Map<String, String> headers;

  @override
  String toString() => 'ResolvedStream(hlsUrl: ' + hlsUrl + ', headers: ' + describeEnumMap(headers) + ')';
}

String describeEnumMap(Map<String, String> map) {
  final entries = map.entries.map((e) => e.key + '=' + e.value).join(',');
  return '{' + entries + '}';
}

