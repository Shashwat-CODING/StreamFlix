class Game {
  final String name;
  final String description;
  final String thumbnail;
  final String url;

  Game({
    required this.name,
    required this.description,
    required this.thumbnail,
    required this.url,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
