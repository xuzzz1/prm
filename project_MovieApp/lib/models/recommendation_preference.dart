class RecommendationPreference {
  final String userId;
  final Map<String, double> categoryAffinity;
  final Map<String, double> countryAffinity;
  final Map<String, double> actorAffinity;
  final Map<String, int> watchCountByCategory;
  final int totalMoviesWatched;
  final List<String> recentWatchedSlugs;
  final List<String> favoriteSlugs;
  final int lastUpdated;

  RecommendationPreference({
    required this.userId,
    this.categoryAffinity = const {},
    this.countryAffinity = const {},
    this.actorAffinity = const {},
    this.watchCountByCategory = const {},
    this.totalMoviesWatched = 0,
    this.recentWatchedSlugs = const [],
    this.favoriteSlugs = const [],
    int? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now().millisecondsSinceEpoch;

  factory RecommendationPreference.empty(String userId) {
    return RecommendationPreference(userId: userId);
  }

  factory RecommendationPreference.fromJson(Map<String, dynamic> json, String userId) {
    return RecommendationPreference(
      userId: userId,
      categoryAffinity: _parseStringDoubleMap(json['category_affinity']),
      countryAffinity: _parseStringDoubleMap(json['country_affinity']),
      actorAffinity: _parseStringDoubleMap(json['actor_affinity']),
      watchCountByCategory: _parseStringIntMap(json['watch_count_by_category']),
      totalMoviesWatched: json['total_movies_watched'] ?? 0,
      recentWatchedSlugs: _parseStringList(json['recent_watched_slugs']),
      favoriteSlugs: _parseStringList(json['favorite_slugs']),
      lastUpdated: json['last_updated'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_affinity': categoryAffinity,
      'country_affinity': countryAffinity,
      'actor_affinity': actorAffinity,
      'watch_count_by_category': watchCountByCategory,
      'total_movies_watched': totalMoviesWatched,
      'recent_watched_slugs': recentWatchedSlugs,
      'favorite_slugs': favoriteSlugs,
      'last_updated': lastUpdated,
    };
  }

  RecommendationPreference copyWith({
    String? userId,
    Map<String, double>? categoryAffinity,
    Map<String, double>? countryAffinity,
    Map<String, double>? actorAffinity,
    Map<String, int>? watchCountByCategory,
    int? totalMoviesWatched,
    List<String>? recentWatchedSlugs,
    List<String>? favoriteSlugs,
    int? lastUpdated,
  }) {
    return RecommendationPreference(
      userId: userId ?? this.userId,
      categoryAffinity: categoryAffinity ?? Map.from(this.categoryAffinity),
      countryAffinity: countryAffinity ?? Map.from(this.countryAffinity),
      actorAffinity: actorAffinity ?? Map.from(this.actorAffinity),
      watchCountByCategory: watchCountByCategory ?? Map.from(this.watchCountByCategory),
      totalMoviesWatched: totalMoviesWatched ?? this.totalMoviesWatched,
      recentWatchedSlugs: recentWatchedSlugs ?? List.from(this.recentWatchedSlugs),
      favoriteSlugs: favoriteSlugs ?? List.from(this.favoriteSlugs),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static Map<String, double> _parseStringDoubleMap(dynamic data) {
    if (data == null) return {};
    final map = <String, double>{};
    (data as Map).forEach((key, value) {
      if (value is num) map[key.toString()] = value.toDouble();
    });
    return map;
  }

  static Map<String, int> _parseStringIntMap(dynamic data) {
    if (data == null) return {};
    final map = <String, int>{};
    (data as Map).forEach((key, value) {
      if (value is num) map[key.toString()] = value.toInt();
    });
    return map;
  }

  static List<String> _parseStringList(dynamic data) {
    if (data == null) return [];
    return (data as List).map((e) => e.toString()).toList();
  }
}
