class Movie {
  final String name;
  final String slug;
  final String thumbUrl;
  final String posterUrl;
  final int year;

  // Metadata available from detail API response
  final String? originName;
  final String? content;
  final String? type; // "series" or "single"
  final List<String> categories; // category slugs
  final Map<String, String> categoryNames; // slug -> display name
  final List<String> countries; // country slugs
  final Map<String, String> countryNames; // slug -> display name
  final List<String> actors;
  final List<String> directors;
  final String? episodeTotal;
  final String? durationLabel; // e.g. "45 phút" or "17 phút/tập"
  final int? viewCount;

  // Playback fields
  int? position;
  int? playbackDuration; // seconds
  String? episodeName;
  int? lastWatchedTimestamp;

  Movie({
    required this.name,
    required this.slug,
    required this.thumbUrl,
    required this.posterUrl,
    required this.year,
    this.originName,
    this.content,
    this.type,
    this.categories = const [],
    this.categoryNames = const {},
    this.countries = const [],
    this.countryNames = const {},
    this.actors = const [],
    this.directors = const [],
    this.episodeTotal,
    this.durationLabel,
    this.viewCount,
    this.position,
    this.playbackDuration,
    this.episodeName,
    this.lastWatchedTimestamp,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      posterUrl: json['poster_url'] ?? '',
      year: json['year'] ?? 0,
      originName: json['origin_name'],
      content: json['content'],
      type: json['type'],
      categories: _flattenToSlugs(json['category']),
      categoryNames: _flattenToNameMap(json['category']),
      countries: _flattenToSlugs(json['country']),
      countryNames: _flattenToNameMap(json['country']),
      actors: _flattenToStrings(json['actor']),
      directors: _flattenToStrings(json['director']),
      episodeTotal: json['episode_total']?.toString(),
      durationLabel: json['time']?.toString(),
      viewCount: json['view'] is int ? json['view'] : null,
      position: json['position'],
      playbackDuration: json['duration'],
      episodeName: json['episode_name'],
      lastWatchedTimestamp: json['last_watched_timestamp'],
    );
  }

  static List<String> _flattenToSlugs(dynamic field) {
    if (field == null) return [];
    return (field as List).map((e) => e['slug']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }

  static Map<String, String> _flattenToNameMap(dynamic field) {
    if (field == null) return {};
    final result = <String, String>{};
    for (var e in field as List) {
      final slug = e['slug']?.toString();
      final name = e['name']?.toString();
      if (slug != null && slug.isNotEmpty && name != null && name.isNotEmpty) {
        result[slug] = name;
      }
    }
    return result;
  }

  static List<String> _flattenToStrings(dynamic field) {
    if (field == null) return [];
    return (field as List).map((e) => e.toString()).where((s) => s.isNotEmpty && s != 'Đang cập nhật').toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'thumb_url': thumbUrl,
      'poster_url': posterUrl,
      'year': year,
      'origin_name': originName,
      'content': content,
      'type': type,
      'position': position,
      'duration': playbackDuration,
      'episode_name': episodeName,
      'last_watched_timestamp': lastWatchedTimestamp,
    };
  }
}


// --- CẤU TRÚC ĐƯỢC THÊM MỚI ĐỂ PHỤC VỤ DANH SÁCH TẬP PHIM ---
class EpisodeServer {
  final String serverName;
  final List<EpisodeDoc> serverData;

  EpisodeServer({required this.serverName, required this.serverData});

  factory EpisodeServer.fromJson(Map<String, dynamic> json) {
    var list = json['server_data'] as List? ?? [];
    List<EpisodeDoc> dataList = list.map((e) => EpisodeDoc.fromJson(e)).toList();
    return EpisodeServer(
      serverName: json['server_name'] ?? '',
      serverData: dataList,
    );
  }
}

class EpisodeDoc {
  final String name;
  final String slug;
  final String filename;
  final String linkEmbed;
  final String linkM3u8;

  EpisodeDoc({
    required this.name,
    required this.slug,
    required this.filename,
    required this.linkEmbed,
    required this.linkM3u8,
  });

  factory EpisodeDoc.fromJson(Map<String, dynamic> json) {
    return EpisodeDoc(
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      filename: json['filename'] ?? '',
      linkEmbed: json['link_embed'] ?? '',
      linkM3u8: json['link_m3u8'] ?? '',
    );
  }
}