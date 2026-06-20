import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/movie_service.dart';
import '../models/movie.dart';
import '../models/app_user.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();
  final MovieService _movieService = MovieService();

  List<String> _bannerSlugs = [];
  List<String> _hiddenSlugs = []; // Danh sách slug bị ẩn
  List<String> _featuredSlugs = []; // Danh sách slug đề cử
  List<AppUser> _users = []; // Danh sách người dùng
  List<Movie> _recentMovies = []; // Danh sách phim mới từ API
  Map<String, dynamic> _stats = {}; // Thống kê dashboard
  bool _isLoading = false;

  List<String> get bannerSlugs => _bannerSlugs;
  List<String> get hiddenSlugs => _hiddenSlugs;
  List<String> get featuredSlugs => _featuredSlugs;
  List<AppUser> get users => _users;
  List<Movie> get recentMovies => _recentMovies;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;

  Future<void> fetchAdminData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load dữ liệu đồng thời để tối ưu hiệu năng
      final results = await Future.wait([
        _adminService.getBannerSlugs(),
        _adminService.getHiddenMovieSlugs(),
        _adminService.getFeaturedMovieSlugs(),
        _adminService.getDashboardStats(),
        _movieService.fetchTrendingMovies(),
        _adminService.getAllUsers(),
      ]);

      _bannerSlugs = results[0] as List<String>;
      _hiddenSlugs = results[1] as List<String>;
      _featuredSlugs = results[2] as List<String>;
      _stats = results[3] as Map<String, dynamic>;
      _recentMovies = results[4] as List<Movie>;
      _users = results[5] as List<AppUser>;
      
      // Sắp xếp: Admin lên đầu
      _sortUsers();
    } catch (e) {
      debugPrint("Lỗi fetchAdminData: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortUsers() {
    _users.sort((a, b) {
      if (a.role == 'admin' && b.role != 'admin') return -1;
      if (a.role != 'admin' && b.role == 'admin') return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase()); // Sắp xếp theo tên nếu cùng role
    });
  }

  Future<void> searchMovies(String query) async {
    if (query.isEmpty) {
      _recentMovies = await _movieService.fetchTrendingMovies();
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    
    try {
      _recentMovies = await _movieService.searchMovies(query);
    } catch (e) {
      debugPrint("Lỗi searchMovies: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Quản lý Ẩn/Hiện phim ---
  Future<void> updateHiddenMovie(String slug, bool hide) async {
    try {
      if (hide) {
        await _adminService.hideMovie(slug);
        if (!_hiddenSlugs.contains(slug)) _hiddenSlugs.add(slug);
      } else {
        await _adminService.unhideMovie(slug);
        _hiddenSlugs.remove(slug);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Lỗi updateHiddenMovie: $e");
    }
  }

  Future<void> toggleHideMovie(String slug) async {
    await updateHiddenMovie(slug, !_hiddenSlugs.contains(slug));
  }

  // --- Quản lý Banner ---
  Future<String?> addBanner(String slug) async {
    if (_bannerSlugs.contains(slug)) return "Phim này đã có trong Banner!";

    _isLoading = true;
    notifyListeners();

    try {
      // Kiểm tra phim tồn tại trước khi add
      final movie = await _movieService.fetchMovieDetail(slug);
      if (movie == null) {
        return "Không tìm thấy phim với Slug này!";
      }

      await _adminService.addBanner(slug);
      _bannerSlugs.add(slug);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeBanner(String slug) async {
    try {
      await _adminService.removeBanner(slug);
      _bannerSlugs.remove(slug);
      notifyListeners();
    } catch (e) {
      debugPrint("Lỗi removeBanner: $e");
    }
  }

  Future<void> updateBannerOrder(List<String> newOrder) async {
    _bannerSlugs = newOrder;
    notifyListeners();
    try {
      await _adminService.updateBanners(newOrder);
    } catch (e) {
      debugPrint("Lỗi updateBannerOrder: $e");
    }
  }

  // --- Quản lý Người dùng ---
  Future<void> toggleUserRole(AppUser user) async {
    final newRole = user.role == 'admin' ? 'user' : 'admin';
    try {
      await _adminService.updateUserRole(user.uid, newRole);
      // Cập nhật local state
      final index = _users.indexWhere((u) => u.uid == user.uid);
      if (index != -1) {
        _users[index] = AppUser(uid: user.uid, name: user.name, email: user.email, role: newRole);
        _sortUsers(); // Sắp xếp lại sau khi đổi role
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Lỗi toggleUserRole: $e");
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _adminService.deleteUserFromDb(uid);
      _users.removeWhere((u) => u.uid == uid);
      notifyListeners();
    } catch (e) {
      debugPrint("Lỗi deleteUser: $e");
    }
  }
}
