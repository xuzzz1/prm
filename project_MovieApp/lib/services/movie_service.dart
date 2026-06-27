import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/movie.dart';

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
  Future<List<Movie>> fetchTrendingMovies() async {
    try {
      final url = Uri.parse(
        '${ApiConstants.baseUrl}/danh-sach/phim-moi-cap-nhat?page=1',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
        final url = Uri.parse(
          '${ApiConstants.baseUrl}/danh-sach/phim-moi-cap-nhat?page=$page',
        );
        final response = await http.get(url);
        final data = jsonDecode(response.body);
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
    final result = List<Movie>.filled(movies.length, movies[0]); // placeholder

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
          result[i + j] = batch[j]; // keep list-item data on failure
        }
      }
    }

    return result;
  }

  /// Merges enriched fields from a detail API response into a Movie.
  /// Only overrides fields that the detail response actually provides (non-null),
  /// preserving list-item data (tmdbVoteAverage, tmdbVoteCount, modifiedTime) when
  /// the detail endpoint doesn't return them.
  Movie _mergeDetailIntoMovie(Movie base, Map<String, dynamic> detail) {
    final item = detail['data']?['item'] ?? {};

    final merged = Map<String, dynamic>.from(base.toJson());

    // Only override if detail provides a non-null value
    void mergeIfPresent(String key, dynamic value) {
      if (value != null) merged[key] = value;
    }

    // Only merge tmdb if it has real data — avoid overwriting valid list values
    // with an empty {} from the detail endpoint
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

    // Only merge modified if it has a non-empty value — avoid overwriting valid
    // modifiedTime from the list endpoint with an empty string from detail
    final modifiedValue = item['modified'];
    if (modifiedValue != null && modifiedValue.toString().trim().isNotEmpty) {
      merged['modified'] = modifiedValue;
    }

    return Movie.fromJson(merged);
  }

  // HÀM MỚI: Gọi API lấy chi tiết phim & danh sách tập phim
  Future<Map<String, dynamic>?> fetchMovieDetail(String slug) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/phim/$slug');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return data; // Trả về Map chứa cả key 'movie' và 'episodes'
        }
      }
    } catch (e) {
      print("Lỗi fetchMovieDetail: $e");
    }
    return null;
  }

  Future<List<Movie>> searchMovies(String keyword) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/v1/api/tim-kiem?keyword=$keyword&limit=20');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
      final url = Uri.parse('${ApiConstants.categoryDetail(categorySlug)}?page=$page&limit=12');
      return _fetchMoviesFromUrl(url);
    } catch (e) {
      print("Lỗi fetchMoviesByCategory: $e");
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }

  Future<Map<String, dynamic>> fetchMoviesByCountry(String countrySlug, int page) async {
    try {
      final url = Uri.parse('https://phimapi.com/v1/api/quoc-gia/$countrySlug?page=$page&limit=12');
      return _fetchMoviesFromUrl(url);
    } catch (e) {
      print("Lỗi fetchMoviesByCountry: $e");
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }

  Future<Map<String, dynamic>> fetchMoviesByType(String type, int page) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/v1/api/danh-sach/$type?page=$page&limit=12');
      return _fetchMoviesFromUrl(url);
    } catch (e) {
      print("Lỗi fetchMoviesByType: $e");
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }

  // Hàm helper dùng chung để parse dữ liệu từ API v1
  Future<Map<String, dynamic>> _fetchMoviesFromUrl(Uri url) async {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      List items = [];
      int totalPages = 1;
      
      if (data['data'] != null && data['data']['items'] != null) {
        items = data['data']['items'];
        totalPages = data['data']['params']?['pagination']?['totalPages'] ?? 1;
      }

      final movies = items.map((json) {
        return Movie.fromJson(json);
      }).toList();
      
      return {
        'movies': movies,
        'totalPages': totalPages,
      };
    }
    return {'movies': <Movie>[], 'totalPages': 1};
  }
}
