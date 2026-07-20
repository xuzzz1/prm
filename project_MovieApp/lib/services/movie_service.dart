import 'dart:convert';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../models/movie.dart';
import 'dio_client.dart';

/// Phase-1 result: contains only list-sorted data, no detail enrichment needed.
/// Home screen can render immediately after receiving this.
class HomeQuickResult {
  final List<Movie> allMovies;
  final List<Movie> bannerMovies;
  final List<Movie> trendingMovies;
  final List<Movie> recentlyUpdatedMovies;
  final DateTime fetchedAt;

  HomeQuickResult({
    required this.allMovies,
    required this.bannerMovies,
    required this.trendingMovies,
    required this.recentlyUpdatedMovies,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'allMovies': allMovies.map((m) => m.toJson()).toList(),
        'bannerMovies': bannerMovies.map((m) => m.toJson()).toList(),
        'trendingMovies': trendingMovies.map((m) => m.toJson()).toList(),
        'recentlyUpdatedMovies': recentlyUpdatedMovies.map((m) => m.toJson()).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory HomeQuickResult.fromJson(Map<String, dynamic> json) {
    return HomeQuickResult(
      allMovies: (json['allMovies'] as List).map((m) => Movie.fromJson(m)).toList(),
      bannerMovies: (json['bannerMovies'] as List).map((m) => Movie.fromJson(m)).toList(),
      trendingMovies: (json['trendingMovies'] as List).map((m) => Movie.fromJson(m)).toList(),
      recentlyUpdatedMovies: (json['recentlyUpdatedMovies'] as List).map((m) => Movie.fromJson(m)).toList(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }
}

class MovieService {
  static const _homeCacheKey = 'home_quick_cache';
  static const _homeCacheMaxAge = Duration(hours: 2);
  SharedPreferences? _prefs;

  Future<DioClient> _getDioClient() async {
    return await DioClient.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<HomeQuickResult?> getCachedHomeResult() async {
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(_homeCacheKey);
      if (raw == null) return null;

      final cached = HomeQuickResult.fromJson(jsonDecode(raw));
      if (DateTime.now().difference(cached.fetchedAt) > _homeCacheMaxAge) {
        await prefs.remove(_homeCacheKey);
        return null;
      }
      return cached;
    } catch (_) {
      return null;
    }
  }

  void invalidateHomeCache() {
    _preferences.then((prefs) => prefs.remove(_homeCacheKey));
  }

  Future<Map<String, dynamic>> _cachedGet(
    String url,
    CacheOptions cacheOptions,
  ) async {
    final dio = (await _getDioClient()).dio;
    final response = await dio.get(
      url,
      options: cacheOptions.toOptions(),
    );
    final raw = response.data;
    if (raw is String) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return (raw ?? {}) as Map<String, dynamic>;
  }

  Future<List<Movie>> fetchTrendingMovies() async {
    final url = '${ApiConstants.baseUrl}/danh-sach/phim-moi-cap-nhat?page=1';
    final data = await _cachedGet(url, (await _getDioClient()).quickListCacheOptions());

    if (data['items'] != null) {
      final List items = data['items'] ?? [];
      return items.map((movieJson) => Movie.fromJson(movieJson)).toList();
    }
    throw Exception('Không thể tải danh sách phim thịnh hành.');
  }

  Future<List<Movie>> fetchAllMovies({int pages = 3}) async {
    final allMovies = <Movie>[];
    for (int page = 1; page <= pages; page++) {
      final url = '${ApiConstants.baseUrl}/danh-sach/phim-moi-cap-nhat?page=$page';
      final cacheOptions = (await _getDioClient()).quickListCacheOptions();
      final data = await _cachedGet(url, cacheOptions);
      final List items = data['items'] ?? [];
      final movies = items.map((json) => Movie.fromJson(json)).toList();
      allMovies.addAll(movies);
    }
    return allMovies;
  }

  /// Phase 1 — fetches 10 list pages, sorts sections, persists to disk, and returns.
  /// No detail enrichment yet. Designed for the home screen's fast-first render.
  Future<HomeQuickResult> fetchMoviesForHomeQuick({int pages = 10}) async {
    final allMovies = await fetchAllMovies(pages: pages);

    final byRating = List<Movie>.from(allMovies)
      ..sort((a, b) => (b.tmdbVoteAverage ?? 0.0).compareTo(a.tmdbVoteAverage ?? 0.0));

    final byVotes = List<Movie>.from(allMovies)
      ..sort((a, b) => (b.tmdbVoteCount ?? 0).compareTo(a.tmdbVoteCount ?? 0));

    final byModified = List<Movie>.from(allMovies)
      ..sort((a, b) {
        final aTime = a.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    final result = HomeQuickResult(
      allMovies: allMovies,
      bannerMovies: byRating.take(10).toList(),
      trendingMovies: byVotes.take(10).toList(),
      recentlyUpdatedMovies: byModified.take(10).toList(),
      fetchedAt: DateTime.now(),
    );

    try {
      final prefs = await _preferences;
      await prefs.setString(_homeCacheKey, jsonEncode(result.toJson()));
    } catch (_) {}

    return result;
  }

  /// Phase 2 — enriches an already-fetched [pool] by batch-fetching details
  /// (10 concurrent at a time) to get real tmdbVoteAverage / tmdbVoteCount.
  /// Returns the enriched pool for use by recommendations/movie-based sections.
  Future<List<Movie>> fetchMoviesForHomeEnriched({required List<Movie> pool}) async {
    return await _fetchDetailsBatched(pool, batchSize: 10);
  }

  /// Fetches movie details in controlled-concurrency batches, returning
  /// enriched Movie objects. Preserves order of the input list.
  Future<List<Movie>> _fetchDetailsBatched(List<Movie> movies, {int batchSize = 10}) async {
    if (movies.isEmpty) return [];
    final result = List<Movie>.filled(movies.length, movies[0]);

    for (int i = 0; i < movies.length; i += batchSize) {
      final end = (i + batchSize < movies.length) ? i + batchSize : movies.length;
      final batch = movies.sublist(i, end);

      final details = await Future.wait(
        batch.map((m) => fetchMovieDetail(m.slug)),
      );

      for (int j = 0; j < batch.length; j++) {
        final detail = details[j];
        if (detail != null) {
          result[i + j] = _mergeDetailIntoMovie(batch[j], detail);
        } else {
          result[i + j] = batch[j];
        }
      }
    }

    return result;
  }

  /// Merges enriched fields from a detail API response into a Movie.
  Movie _mergeDetailIntoMovie(Movie base, Map<String, dynamic> detail) {
    final item = detail['data']?['item'] ?? {};
    final merged = Map<String, dynamic>.from(base.toJson());

    void mergeIfPresent(String key, dynamic value) {
      if (value != null) merged[key] = value;
    }

    final tmdbValue = item['tmdb'];
    if (tmdbValue != null && (tmdbValue is Map) && tmdbValue.isNotEmpty) {
      merged['tmdb'] = tmdbValue;
    }

    mergeIfPresent('content', item['content']);
    mergeIfPresent('type', item['type']);
    mergeIfPresent('time', item['time']);
    mergeIfPresent('episode_total', item['episode_total']);
    mergeIfPresent('view', item['view']);
    mergeIfPresent('category', item['category']);
    mergeIfPresent('country', item['country']);
    mergeIfPresent('actor', item['actor']);
    mergeIfPresent('director', item['director']);

    final modifiedValue = item['modified'];
    if (modifiedValue != null && modifiedValue.toString().trim().isNotEmpty) {
      merged['modified'] = modifiedValue;
    }

    return Movie.fromJson(merged);
  }

  Future<Map<String, dynamic>?> fetchMovieDetail(String slug) async {
    final url = '${ApiConstants.baseUrl}/phim/$slug';
    final data = await _cachedGet(url, (await _getDioClient()).detailCacheOptions());

    if (data['status'] == true) {
      return data;
    }
    return null;
  }

  Future<List<Movie>> searchMovies(String keyword) async {
    final url = '${ApiConstants.baseUrl}/v1/api/tim-kiem?keyword=$keyword&limit=20';
    final data = await _cachedGet(url, (await _getDioClient()).searchCacheOptions());

    if (data['status'] == 'success' || data['data'] != null) {
      final List items = data['data']?['items'] ?? [];

      return items.map((json) {
        return Movie(
          name: json['name'] ?? '',
          slug: json['slug'] ?? '',
          thumbUrl: json['thumb_url'] ?? '',
          posterUrl: json['poster_url'] ?? '',
          year: json['year'] ?? 0,
        );
      }).toList();
    }
    throw Exception('Không thể tìm kiếm. Vui lòng thử lại.');
  }

  Future<Map<String, dynamic>> fetchMoviesByCategory(String categorySlug, int page) async {
    try {
      final url = '${ApiConstants.categoryDetail(categorySlug)}?page=$page&limit=12';
      return _fetchMoviesFromUrl(url, (await _getDioClient()).categoryCacheOptions());
    } catch (e) {
      // Silently handle
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }

  Future<Map<String, dynamic>> fetchMoviesByCountry(String countrySlug, int page) async {
    try {
      final url = 'https://phimapi.com/v1/api/quoc-gia/$countrySlug?page=$page&limit=12';
      return _fetchMoviesFromUrl(url, (await _getDioClient()).categoryCacheOptions());
    } catch (e) {
      // Silently handle
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }

  Future<Map<String, dynamic>> fetchMoviesByType(String type, int page) async {
    try {
      final url = '${ApiConstants.baseUrl}/v1/api/danh-sach/$type?page=$page&limit=12';
      return _fetchMoviesFromUrl(url, (await _getDioClient()).categoryCacheOptions());
    } catch (e) {
      // Silently handle
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }

  Future<Map<String, dynamic>> _fetchMoviesFromUrl(String url, CacheOptions cacheOptions) async {
    try {
      final data = await _cachedGet(url, cacheOptions);

      List items = [];
      int totalPages = 1;

      if (data['data'] != null && data['data']['items'] != null) {
        items = data['data']['items'];
        totalPages = data['data']['params']?['pagination']?['totalPages'] ?? 1;
      }

      final movies = items.map((json) => Movie.fromJson(json)).toList();

      return {
        'movies': movies,
        'totalPages': totalPages,
      };
    } catch (e) {
      return {'movies': <Movie>[], 'totalPages': 1};
    }
  }
}
