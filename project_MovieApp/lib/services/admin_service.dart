import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';
import 'movie_service.dart';

class AdminService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final MovieService _movieService = MovieService();

  // --- QUẢN LÝ BANNER (SLIDER TRANG CHỦ) ---
  
  // Lấy danh sách slug phim làm banner
  Future<List<String>> getBannerSlugs() async {
    final snapshot = await _db.ref('settings/banners').get();
    if (snapshot.exists) {
      final data = snapshot.value as List<dynamic>;
      return data.cast<String>();
    }
    return [];
  }

  // Thêm một phim vào banner
  Future<void> addBanner(String slug) async {
    List<String> banners = await getBannerSlugs();
    if (!banners.contains(slug)) {
      banners.add(slug);
      await _db.ref('settings/banners').set(banners);
    }
  }

  // Xóa phim khỏi banner
  Future<void> removeBanner(String slug) async {
    List<String> banners = await getBannerSlugs();
    banners.remove(slug);
    await _db.ref('settings/banners').set(banners);
  }

  // --- QUẢN LÝ PHIM (QUICK ADD) ---

  // Thêm phim vào danh sách "Đề cử" của Admin
  Future<bool> addFeaturedMovie(String slug) async {
    try {
      // Kiểm tra xem phim có tồn tại trên API không
      final detail = await _movieService.fetchMovieDetail(slug);
      if (detail != null) {
        // Lưu slug vào danh sách đề cử trên Firebase
        await _db.ref('settings/featured_movies/$slug').set(true);
        return true;
      }
    } catch (e) {
      print("Lỗi addFeaturedMovie: $e");
    }
    return false;
  }

  // Xóa khỏi danh sách đề cử
  Future<void> removeFeaturedMovie(String slug) async {
    await _db.ref('settings/featured_movies/$slug').remove();
  }

  // --- THỐNG KÊ (DUMMY DATA FOR NOW) ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    // Trong thực tế, bạn sẽ đếm số lượng bản ghi trong database
    return {
      "users": "1,248",
      "movies": "16",
      "views": "33.9M",
      "active_now": "3,842",
    };
  }
}
