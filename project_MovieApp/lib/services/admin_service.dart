import 'package:firebase_database/firebase_database.dart';
import '../models/app_user.dart';
import 'movie_service.dart';

class AdminService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final MovieService _movieService = MovieService();

  // --- QUẢN LÝ BANNER (SLIDER TRANG CHỦ) ---
  
  // Lấy danh sách slug phim làm banner
  Future<List<String>> getBannerSlugs() async {
    final snapshot = await _db.ref('settings/banners').get();
    if (snapshot.exists) {
      final value = snapshot.value;
      if (value is List) {
        return value.cast<String>();
      } else if (value is Map) {
        // Firebase đôi khi trả về Map nếu có index bị nhảy
        return value.values.cast<String>().toList();
      }
    }
    return [];
  }

  // Cập nhật toàn bộ danh sách banner (dùng cho reorder)
  Future<void> updateBanners(List<String> slugs) async {
    await _db.ref('settings/banners').set(slugs);
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

  // --- QUẢN LÝ PHIM (QUICK ADD & HIDE) ---

  // Lấy danh sách các slug phim bị ẩn
  Future<List<String>> getHiddenMovieSlugs() async {
    final snapshot = await _db.ref('settings/hidden_movies').get();
    if (snapshot.exists) {
      final data = snapshot.value;
      if (data is Map) {
        return data.keys.cast<String>().toList();
      } else if (data is List) {
        // Trường hợp hy hữu nếu data lưu dạng list
        return data.cast<String>();
      }
    }
    return [];
  }

  // Ẩn một bộ phim
  Future<void> hideMovie(String slug) async {
    await _db.ref('settings/hidden_movies/$slug').set(true);
  }

  // Bỏ ẩn một bộ phim
  Future<void> unhideMovie(String slug) async {
    await _db.ref('settings/hidden_movies/$slug').remove();
  }

  // Lấy danh sách slug phim được đề cử
  Future<List<String>> getFeaturedMovieSlugs() async {
    final snapshot = await _db.ref('settings/featured_movies').get();
    if (snapshot.exists) {
      final data = snapshot.value;
      if (data is Map) {
        return data.keys.cast<String>().toList();
      }
    }
    return [];
  }

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
      // Non-critical: movie validation failed
    }
    return false;
  }

  // Xóa khỏi danh sách đề cử
  Future<void> removeFeaturedMovie(String slug) async {
    await _db.ref('settings/featured_movies/$slug').remove();
  }

  // --- THỐNG KÊ (DUMMY DATA FOR NOW) ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final usersSnapshot = await _db.ref('users').get();

      int userCount = 0;
      if (usersSnapshot.exists) {
        final data = usersSnapshot.value as Map;
        userCount = data.length;
      }

      return {
        "users": userCount.toString(),
        "movies": "16", // Giữ nguyên dummy cho đến khi có danh sách phim db
        "views": "33.9M",
        "active_now": "5",
      };
    } catch (e) {
      return {
        "users": "1,248",
        "movies": "16",
        "views": "33.9M",
        "active_now": "3,842",
      };
    }
  }

  // --- QUẢN LÝ NGƯỜI DÙNG ---

  // Lấy toàn bộ danh sách user từ Database
  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _db.ref('users').get();
      if (snapshot.exists) {
        final data = snapshot.value;

        if (data is Map) {
          final List<AppUser> users = [];
          data.forEach((key, value) {
            try {
              users.add(AppUser.fromMap(key.toString(), Map<dynamic, dynamic>.from(value as Map)));
            } catch (_) {
              // Skip malformed user records
            }
          });
          return users;
        }
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  // Cập nhật Role cho user
  Future<void> updateUserRole(String uid, String newRole) async {
    await _db.ref('users/$uid/role').set(newRole);
  }

  // Xóa user (Chỉ xóa khỏi Database, Firebase Auth cần Admin SDK để xóa hẳn)
  Future<void> deleteUserFromDb(String uid) async {
    await _db.ref('users/$uid').remove();
  }
}
