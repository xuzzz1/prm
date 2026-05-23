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
  // Thêm vào trong class MovieService ở file lib/services/movie_service.dart

  Future<List<Movie>> searchMovies(String keyword) async {
    try {
      // API tìm kiếm chính thức của phimapi.com
      final url = Uri.parse('${ApiConstants.baseUrl}/v1/api/tim-kiem?keyword=$keyword&limit=20');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' || data['data'] != null) {
          final List items = data['data']['items'] ?? [];

          // API kết quả tìm kiếm trả về đường dẫn ảnh gốc trực tiếp (không qua image.php)
          // Nên chúng ta bóc tách map dữ liệu tương thích với Model Movie của bạn
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
  // Thêm vào trong class MovieService ở file lib/services/movie_service.dart

  Future<List<Movie>> fetchMoviesByCategory(String categorySlug, int page) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/v1/api/the-loai/$categorySlug?page=$page');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
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
      print("Lỗi fetchMoviesByCategory: $e");
    }
    return [];
  }
}