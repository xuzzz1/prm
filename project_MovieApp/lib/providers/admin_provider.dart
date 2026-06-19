import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/movie_service.dart';
import '../models/movie.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();
  final MovieService _movieService = MovieService();

  List<String> _bannerSlugs = [];
  List<Movie> _recentMovies = []; // Thêm danh sách phim mới từ API
  bool _isLoading = false;

  List<String> get bannerSlugs => _bannerSlugs;
  List<Movie> get recentMovies => _recentMovies;
  bool get isLoading => _isLoading;

  Future<void> fetchAdminData() async {
    _isLoading = true;
    notifyListeners();

    _bannerSlugs = await _adminService.getBannerSlugs();
    // Lấy thêm danh sách phim mới để gợi ý slug
    _recentMovies = await _movieService.fetchTrendingMovies();

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> addBanner(String slug) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Kiểm tra phim tồn tại trước khi add
      final movie = await _movieService.fetchMovieDetail(slug);
      if (movie == null) {
        _isLoading = false;
        notifyListeners();
        return "Không tìm thấy phim với Slug này!";
      }

      await _adminService.addBanner(slug);
      _bannerSlugs.add(slug);
      
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> removeBanner(String slug) async {
    await _adminService.removeBanner(slug);
    _bannerSlugs.remove(slug);
    notifyListeners();
  }
}
