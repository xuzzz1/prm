import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/movie.dart';

class MovieService {
  Future<List<Movie>> fetchTrendingMovies() async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/danh-sach/phim-moi-cap-nhat?page=1',
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);
    final List items = data['items'];

    return items.map((movieJson) => Movie.fromJson(movieJson)).toList();
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
