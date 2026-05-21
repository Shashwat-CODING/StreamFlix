class AudioQuality {
  final String label;
  final String url;
  const AudioQuality({required this.label, required this.url});
}

class SongModel {
  final String id;
  final String name;
  final String artistName;
  final String? imageUrl;
  final String? downloadUrl; // default (highest) quality
  final List<AudioQuality> qualities;
  final int durationSeconds;

  SongModel({
    required this.id,
    required this.name,
    required this.artistName,
    this.imageUrl,
    this.downloadUrl,
    this.qualities = const [],
    required this.durationSeconds,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    String artist = json['artistName']?.toString() ?? 'Unknown Artist';
    if (json['artist'] is String) {
      artist = json['artist'];
    } else if (json['artists'] != null && json['artists'] is List) {
      final List allArtists = json['artists'];
      if (allArtists.isNotEmpty) {
        artist = allArtists.map((a) {
          if (a is String) return a;
          return a['name']?.toString() ?? 'Unknown';
        }).join(', ');
      }
    }

    String? image = json['imageUrl']?.toString() ?? json['thumbnail']?.toString();
    if (json['thumbnails'] != null && json['thumbnails'] is List) {
      final List images = json['thumbnails'];
      if (images.isNotEmpty) {
        image = images.last['url']?.toString();
      }
    }

    if (image != null) {
      image = image.replaceAll(RegExp(r'-[a-zA-Z0-9]+$'), '');
      if (image.contains('=')) {
        image = image.replaceAll(RegExp(r'=w\d+-h\d+.*'), '=w500-h500');
      }
    }

    int durationSecs = json['durationSeconds'] ?? 0;
    if (json['duration_seconds'] != null) {
      durationSecs = int.tryParse(json['duration_seconds'].toString()) ?? 0;
    } else if (json['duration'] != null) {
      String durStr = json['duration'].toString();
      if (durStr.contains(':')) {
        List<String> parts = durStr.split(':');
        if (parts.length == 2) {
          durationSecs = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        } else if (parts.length == 3) {
          durationSecs = (int.tryParse(parts[0]) ?? 0) * 3600 + (int.tryParse(parts[1]) ?? 0) * 60 + (int.tryParse(parts[2]) ?? 0);
        }
      } else {
        durationSecs = int.tryParse(durStr) ?? 0;
      }
    }

    return SongModel(
      id: json['videoId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['title']?.toString() ?? json['name']?.toString() ?? 'Unknown Song',
      artistName: artist,
      imageUrl: image,
      downloadUrl: null,
      qualities: [],
      durationSeconds: durationSecs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': id,
      'id': id,
      'title': name,
      'name': name,
      'artist': artistName,
      'artistName': artistName,
      'thumbnail': imageUrl,
      'imageUrl': imageUrl,
      'duration_seconds': durationSeconds,
      'durationSeconds': durationSeconds,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

