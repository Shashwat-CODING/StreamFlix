import 'dart:convert';
import 'package:http/http.dart' as http;
import '../player/stream_resolution.dart';

class HlstrServerResolver {
  static const String _apiBase = 'http://34.171.138.150:3000/hlstr/';
  static const String _ua = 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Mobile Safari/537.36';

  Future<ResolvedStream> resolve({required String id}) async {
    final resp = await http.get(Uri.parse(_apiBase + id), headers: const {
      'User-Agent': _ua,
      'Accept': '*/*',
      'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br, zstd',
      'Connection': 'keep-alive',
      'Priority': 'u=1, i',
    });
    if (resp.statusCode != 200) {
      throw Exception('HLSTR failed with ' + resp.statusCode.toString());
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final hlsUrl = (data['hlsUrl'] ?? '').toString();
    if (hlsUrl.isEmpty) throw Exception('HLSTR missing hlsUrl');
    final headers = <String, String>{
      'User-Agent': _ua,
      'Accept': '*/*',
      'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br, zstd',
      'Connection': 'keep-alive',
      'Origin': (data['headers']?['origin'] ?? 'https://vidora.stream').toString(),
      'Referer': (data['headers']?['referer'] ?? 'https://vidora.stream/').toString(),
      'Priority': 'u=1, i',
      'sec-ch-ua': '"Not;A=Brand";v="99", "Google Chrome";v="139", "Chromium";v="139"',
      'sec-ch-ua-mobile': '?1',
      'sec-ch-ua-platform': '"Android"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'cross-site',
    };
    return ResolvedStream(hlsUrl: hlsUrl, headers: headers);
  }
}


