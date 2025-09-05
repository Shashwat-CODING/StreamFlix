import '../player/stream_resolution.dart';

class DirectServerResolver {
  static const String _defaultReferer = 'https://vidsrc.cc';
  static const String _ua = 'Mozilla/5.0 (Linux; Android 12; Flutter) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  Future<ResolvedStream> resolve({required String url, String? referer}) async {
    final headers = <String, String>{
      'User-Agent': _ua,
      'Accept': '*/*',
      'Origin': _defaultReferer,
      'Referer': referer ?? _defaultReferer,
      'Connection': 'keep-alive',
    };
    return ResolvedStream(hlsUrl: url, headers: headers);
  }
}


