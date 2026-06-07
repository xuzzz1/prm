// lib/providers/movie_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';

class MovieProvider extends ChangeNotifier {
  final MovieService _movieService = MovieService();

  Map<String, dynamic>? _movieDetailData;
  List<EpisodeServer> _episodes = [];
  List<Movie> _relatedMovies = [];
  bool _isLoadingDetail = false;

  // Danh sách phim yêu thích
  List<Movie> _favoriteMovies = [];

  Map<String, dynamic>? get movieDetailData => _movieDetailData;
  List<EpisodeServer> get episodes => _episodes;
  List<Movie> get relatedMovies => _relatedMovies;
  bool get isLoadingDetail => _isLoadingDetail;
  List<Movie> get favoriteMovies => _favoriteMovies;

  MovieProvider() {
    loadFavorites(); // Tự động tải danh sách phim đã lưu khi khởi tạo app
  }

  Future<void> loadMovieDetail(String slug) async {
    // CHỐNG RELOAD: Nếu đang xem phim này rồi thì không load lại từ API
    if (_movieDetailData != null && _movieDetailData!['slug'] == slug) {
      return; 
    }

    _isLoadingDetail = true;
    _movieDetailData = null;
    _episodes = [];
    _relatedMovies = [];
    notifyListeners();

    final result = await _movieService.fetchMovieDetail(slug);
    if (result != null) {
      _movieDetailData = result['movie'];
      var epList = result['episodes'] as List? ?? [];
      _episodes = epList.map((e) => EpisodeServer.fromJson(e)).toList();

      // Tải phim liên quan dựa trên category đầu tiên
      final categories = _movieDetailData?['category'] as List?;
      if (categories != null && categories.isNotEmpty) {
        final categorySlug = categories[0]['slug'];
        final relatedData = await _movieService.fetchMoviesByCategory(categorySlug, 1);
        _relatedMovies = (relatedData['movies'] as List<Movie>)
            .where((m) => m.slug != slug) // Loại bỏ phim hiện tại
            .take(12) // Lấy tối đa 12 phim
            .toList();
      }
    }

    _isLoadingDetail = false;
    notifyListeners();
  }

  // --- LOGIC XỬ LÝ SHAREDPREFERENCES (FAVORITE) ---

  // 1. Tải danh sách phim yêu thích từ bộ nhớ máy
  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedList = prefs.getStringList('favorite_movies');

    if (savedList != null) {
      _favoriteMovies = savedList.map((item) {
        return Movie.fromJson(jsonDecode(item));
      }).toList();
      notifyListeners();
    }
  }

  // 2. Kiểm tra bộ phim hiện tại đã được yêu thích chưa
  bool isFavorite(String slug) {
    return _favoriteMovies.any((movie) => movie.slug == slug);
  }

  // 3. Thêm hoặc Xóa phim khỏi danh sách yêu thích (Toggle)
  Future<void> toggleFavorite(Movie movie) async {
    final prefs = await SharedPreferences.getInstance();

    if (isFavorite(movie.slug)) {
      // Nếu có rồi thì Xóa
      _favoriteMovies.removeWhere((item) => item.slug == movie.slug);
    } else {
      // Nếu chưa có thì Thêm
      _favoriteMovies.add(movie);
    }

    // Lưu lại danh sách mới vào bộ nhớ máy dưới dạng chuỗi String JSON
    List<String> encodeList = _favoriteMovies.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('favorite_movies', encodeList);

    notifyListeners(); // Cập nhật lại giao diện ngay lập tức
  }
}