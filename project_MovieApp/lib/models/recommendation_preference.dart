class RecommendationPreference {
  final String userId;
  final Map<String, double> categoryAffinity;
  final Map<String, double> countryAffinity;
  final Map<String, double> actorAffinity;
  final List<String> watchedSlugs;
  final int totalMoviesWatched;
  final List<String> recentWatchedSlugs;
  final List<String> favoriteSlugs;
  final int lastUpdated;

  // Cached full movie data for recently watched movies (for scoring similarity)
  final Map<String, Map<String, dynamic>> watchedMoviesCache;

  RecommendationPreference({
    required this.userId,
    this.categoryAffinity = const {},
    this.countryAffinity = const {},
    this.actorAffinity = const {},
    this.watchedSlugs = const [],
    this.totalMoviesWatched = 0,
    this.recentWatchedSlugs = const [],
    this.favoriteSlugs = const [],
    int? lastUpdated,
    this.watchedMoviesCache = const {},
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
      watchedSlugs: _parseStringList(json['watched_slugs'] ?? json['recent_watched_slugs']),
      totalMoviesWatched: json['total_movies_watched'] ?? 0,
      recentWatchedSlugs: _parseStringList(json['recent_watched_slugs']),
      favoriteSlugs: _parseStringList(json['favorite_slugs']),
      lastUpdated: json['last_updated'],
      watchedMoviesCache: _parseWatchedMoviesCache(json['watched_movies_cache']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_affinity': categoryAffinity,
      'country_affinity': countryAffinity,
      'actor_affinity': actorAffinity,
      'watched_slugs': watchedSlugs,
      'total_movies_watched': totalMoviesWatched,
      'recent_watched_slugs': recentWatchedSlugs,
      'favorite_slugs': favoriteSlugs,
      'last_updated': lastUpdated,
      'watched_movies_cache': watchedMoviesCache,
    };
  }

  RecommendationPreference copyWith({
    String? userId,
    Map<String, double>? categoryAffinity,
    Map<String, double>? countryAffinity,
    Map<String, double>? actorAffinity,
    List<String>? watchedSlugs,
    int? totalMoviesWatched,
    List<String>? recentWatchedSlugs,
    List<String>? favoriteSlugs,
    int? lastUpdated,
    Map<String, Map<String, dynamic>>? watchedMoviesCache,
  }) {
    return RecommendationPreference(
      userId: userId ?? this.userId,
      categoryAffinity: categoryAffinity ?? Map.from(this.categoryAffinity),
      countryAffinity: countryAffinity ?? Map.from(this.countryAffinity),
      actorAffinity: actorAffinity ?? Map.from(this.actorAffinity),
      watchedSlugs: watchedSlugs ?? List.from(this.watchedSlugs),
      totalMoviesWatched: totalMoviesWatched ?? this.totalMoviesWatched,
      recentWatchedSlugs: recentWatchedSlugs ?? List.from(this.recentWatchedSlugs),
      favoriteSlugs: favoriteSlugs ?? List.from(this.favoriteSlugs),
      lastUpdated: lastUpdated ?? this.lastUpdated,
      watchedMoviesCache: watchedMoviesCache ?? Map.from(this.watchedMoviesCache),
    );
  }

  static Map<String, Map<String, dynamic>> _parseWatchedMoviesCache(dynamic data) {
    if (data == null) return {};
    final result = <String, Map<String, dynamic>>{};
    (data as Map).forEach((key, value) {
      if (value is Map) {
        result[key.toString()] = Map<String, dynamic>.from(value);
      }
    });
    return result;
  }

  static Map<String, double> _parseStringDoubleMap(dynamic data) {
    if (data == null) return {};
    final map = <String, double>{};
    (data as Map).forEach((key, value) {
      if (value is num) map[key.toString()] = value.toDouble();
    });
    return map;
  }

  static List<String> _parseStringList(dynamic data) {
    if (data == null) return [];
    return (data as List).map((e) => e.toString()).toList();
  }
}
