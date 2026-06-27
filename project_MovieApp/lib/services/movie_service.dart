import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
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

  HomeQuickResult({
    required this.allMovies,
    required this.bannerMovies,
    required this.trendingMovies,
    required this.recentlyUpdatedMovies,
  });
}

class MovieService {
  late Dio _dio;
  late DioClient _dioClient;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _dioClient = await DioClient.getInstance();
    _dio = _dioClient.dio;
    _initialized = true;
  }

  Future<Response<dynamic>> _cachedGet(
    String url,
    CacheOptions cacheOptions,
  ) async {
    await _ensureInitialized();
    return _dio.get(
      url,
      options: cacheOptions.toOptions(),
    );
  }

  Future<List<Movie>> fetchTrendingMovies() async {
    try {
      final url = '${ApiConstants.baseUrl}/danh-sach/phim-moi-cap-nhat?page=1';
      final response = await _cachedGet(url, _dioClient.quickListCacheOptions());

      if (response.statusCode == 200) {
        final data = response.data;
        final List items = data['items'] ?? [];
        return items.map((movieJson) => Movie.fromJson(movieJson)).toList();
      }
    } catch (e) {
      print('Error fetching trending movies: $e');
    }
    return [];
  }

  Future<List<Movie>> fetchAllMovies({int pages = 3}) async {
    final allMovies = <Movie>[];
    for (int page = 1; page <= pages; page++) {
      try {
        final url = '${ApiConstants.baseUrl}/danh-sach/phim-moi-cap-nhat?page=$page';
        final cacheOptions = _dioClient.quickListCacheOptions();
        final response = await _cachedGet(url, cacheOptions);
        final data = response.data;
        final List items = data['items'] ?? [];
        final movies = items.map((json) => Movie.fromJson(json)).toList();
        allMovies.addAll(movies);
      } catch (e) {
        print('Error fetching movies page $page: $e');
      }
    }
    return allMovies;
  }

  /// Phase 1 — fetches 10 list pages, sorts sections, and returns immediately.
  /// No detail enrichment yet. Designed for the home screen's fast-first render.
  Future<HomeQuickResult> fetchMoviesForHomeQuick({int pages = 10}) async {
    final allMovies = await fetchAllMovies(pages: pages);

    print('=== PHASE 1: ALL MOVIES (${allMovies.length}) ===');
    for (final m in allMovies) {
      print('${m.name} | tmdbVoteAverage: ${m.tmdbVoteAverage} | tmdbVoteCount: ${m.tmdbVoteCount} | modifiedTime: ${m.modifiedTime}');
    }
    print('=== END PHASE 1 ===');

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

    return HomeQuickResult(
      allMovies: allMovies,
      bannerMovies: byRating.take(10).toList(),
      trendingMovies: byVotes.take(10).toList(),
      recentlyUpdatedMovies: byModified.take(10).toList(),
    );
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
    try {
      final url = '${ApiConstants.baseUrl}/phim/$slug';
      final response = await _cachedGet(url, _dioClient.detailCacheOptions());

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == true) {
          return data;
        }
      }
    } catch (e) {
      print("Lỗi fetchMovieDetail: $e");
    }
    return null;
  }

  Future<List<Movie>> searchMovies(String keyword) async {
    try {
      final url = '${ApiConstants.baseUrl}/v1/api/tim-kiem?keyword=$keyword&limit=20';
      final response = await _cachedGet(url, _dioClient.searchCacheOptions());

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'success' || data['data'] != null) {
          final List items = data['data']['items'] ?? [];

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
      }
    } catch (e) {
      print("Lỗi searchMovies: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchMoviesByCategory(String categorySlug, int page) async {
    try {
      final url = '${ApiConstants.categoryDetail(categorySlug)}?page=$page&limit=12';
      return _fetchMoviesFromUrl(url, _dioClient.categoryCacheOptions());
    } catch (e) {
      print("Lỗi fetchMoviesByCategory: $e");
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }

  Future<Map<String, dynamic>> fetchMoviesByCountry(String countrySlug, int page) async {
    try {
      final url = 'https://phimapi.com/v1/api/quoc-gia/$countrySlug?page=$page&limit=12';
      return _fetchMoviesFromUrl(url, _dioClient.categoryCacheOptions());
    } catch (e) {
      print("Lỗi fetchMoviesByCountry: $e");
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }

  Future<Map<String, dynamic>> fetchMoviesByType(String type, int page) async {
    try {
      final url = '${ApiConstants.baseUrl}/v1/api/danh-sach/$type?page=$page&limit=12';
      return _fetchMoviesFromUrl(url, _dioClient.categoryCacheOptions());
    } catch (e) {
      print("Lỗi fetchMoviesByType: $e");
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }

  Future<Map<String, dynamic>> _fetchMoviesFromUrl(String url, CacheOptions cacheOptions) async {
    try {
      final response = await _cachedGet(url, cacheOptions);
      final data = response.data;

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
