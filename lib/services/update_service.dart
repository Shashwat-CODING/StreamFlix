import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String repoOwner = 'Shashwat-CODING-1';
  static const String repoName = 'StreamFlix';
  static const String apiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestTag = data['tag_name'] as String; // e.g., "v1.5"
        final changelog = data['body'] as String?;
        final downloadUrl = data['html_url'] as String;

        final packageInfo = await PackageInfo.fromPlatform();
        // The user says current is v1.6. Package info might say 1.0.0.
        // Let's use a standard comparison.

        final currentVersion = _cleanVersion(packageInfo.version);
        final latestVersion = _cleanVersion(latestTag);

        // For the sake of the user request's specific versions mentioned:
        // current v1.6 vs github v1.5 -> no update.
        // But if they want to TEST it, their request might imply 1.5 is new.
        // I will implement "latest > current" check.

        if (_isNewer(latestVersion, currentVersion)) {
          return {
            'version': latestTag,
            'changelog': changelog,
            'url': downloadUrl,
          };
        }
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
    return null;
  }

  static String _cleanVersion(String v) {
    if (v.startsWith('v')) return v.substring(1);
    return v;
  }

  static bool _isNewer(String latest, String current) {
    List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < l.length && i < c.length; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return l.length > c.length;
  }
}
