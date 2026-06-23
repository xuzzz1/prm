// lib/providers/movie_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../services/recommendation_service.dart';

class MovieProvider extends ChangeNotifier {
  final MovieService _movieService = MovieService();
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RecommendationService _recommendationService = RecommendationService();

  Movie? _movieDetail;
  List<EpisodeServer> _episodes = [];
  List<Movie> _relatedMovies = [];
  bool _isLoadingDetail = false;

  // Danh sách phim yêu thích
  List<Movie> _favoriteMovies = [];
  // Danh sách lịch sử xem phim
  List<Movie> _watchHistory = [];
  // Danh sách slug bị ẩn từ Admin
  Set<String> _hiddenSlugs = {};

  Movie? get movieDetail => _movieDetail;
  List<EpisodeServer> get episodes => _episodes;
  List<Movie> get relatedMovies => _relatedMovies;
  bool get isLoadingDetail => _isLoadingDetail;
  List<Movie> get favoriteMovies => _favoriteMovies;
  List<Movie> get watchHistory => _watchHistory;
  Set<String> get hiddenSlugs => _hiddenSlugs;

  MovieProvider() {
    loadFavorites(); // Tự động tải danh sách phim đã lưu khi khởi tạo app
    loadWatchHistory(); // Tải lịch sử xem phim
    loadHiddenSlugs(); // Tải danh sách phim bị ẩn
    
    // Lắng nghe khi user đăng nhập/đăng xuất để sync Firebase
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        syncHistoryFromFirebase();
      } else {
        _watchHistory.clear();
        notifyListeners();
      }
    });
  }

  Future<void> loadMovieDetail(String slug) async {
    // CHỐNG RELOAD: Nếu đang xem phim này rồi thì không load lại từ API
    if (_movieDetail != null && _movieDetail!.slug == slug) {
      return;
    }

    _isLoadingDetail = true;
    _movieDetail = null;
    _episodes = [];
    _relatedMovies = [];
    notifyListeners();

    final result = await _movieService.fetchMovieDetail(slug);
    if (result != null) {
      // Build a fully-enriched Movie from the detail response
      _movieDetail = Movie.fromJson(result['movie'] as Map<String, dynamic>);
      var epList = result['episodes'] as List? ?? [];
      _episodes = epList.map((e) => EpisodeServer.fromJson(e)).toList();

      // Tải phim liên quan dựa trên category đầu tiên
      if (_movieDetail!.categories.isNotEmpty) {
        final categorySlug = _movieDetail!.categories.first;
        final relatedData = await _movieService.fetchMoviesByCategory(categorySlug, 1);
        _relatedMovies = (relatedData['movies'] as List<Movie>)
            .where((m) => m.slug != slug)
            .take(12)
            .toList();
      }
    }

    _isLoadingDetail = false;
    notifyListeners();
  }

  /// Force reload movie detail to get fresh m3u8 URLs (tokens expire quickly)
  Future<void> forceReloadMovie(String slug) async {
    _isLoadingDetail = true;
    _movieDetail = null;
    _episodes = [];
    notifyListeners();

    final result = await _movieService.fetchMovieDetail(slug);
    if (result != null) {
      _movieDetail = Movie.fromJson(result['movie'] as Map<String, dynamic>);
      var epList = result['episodes'] as List? ?? [];
      _episodes = epList.map((e) => EpisodeServer.fromJson(e)).toList();
    }

    _isLoadingDetail = false;
    notifyListeners();
  }

  // --- LOGIC XỬ LÝ PHIM BỊ ẨN (HIDDEN MOVIES) ---

  void loadHiddenSlugs() {
    _db.ref('settings/hidden_movies').onValue.listen((event) {
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        _hiddenSlugs = data.keys.cast<String>().toSet();
      } else {
        _hiddenSlugs = {};
      }
      notifyListeners();
    });
  }

  // Hàm helper để lọc phim bị ẩn
  List<Movie> filterHiddenMovies(List<Movie> movies) {
    if (_hiddenSlugs.isEmpty) return movies;
    return movies.where((m) => !_hiddenSlugs.contains(m.slug)).toList();
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
    final wasFavorite = isFavorite(movie.slug);

    if (wasFavorite) {
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

    // Affinity tracking
    _recommendationService.updateAffinityFromFavorite(movie, !wasFavorite);
  }

  // --- LOGIC XỬ LÝ LỊCH SỬ XEM PHIM (WATCH HISTORY) ---

  // 1. Tải lịch sử từ bộ nhớ máy (Local)
  Future<void> loadWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedList = prefs.getStringList('watch_history');

    if (savedList != null) {
      _watchHistory = savedList.map((item) {
        return Movie.fromJson(jsonDecode(item));
      }).toList();
      notifyListeners();
    }
  }

  // 2. Đồng bộ từ Firebase về Local (Sync)
  Future<void> syncHistoryFromFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _db.ref('watch_history/${user.uid}').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        
        List<Movie> firebaseHistory = [];
        data.forEach((key, value) {
          firebaseHistory.add(Movie.fromJson(Map<String, dynamic>.from(value)));
        });

        // Sắp xếp theo timestamp mới nhất
        firebaseHistory.sort((a, b) => (b.lastWatchedTimestamp ?? 0).compareTo(a.lastWatchedTimestamp ?? 0));

        // Merge với Local (ưu tiên cái nào có timestamp mới hơn)
        for (var fMovie in firebaseHistory) {
          int localIdx = _watchHistory.indexWhere((m) => m.slug == fMovie.slug);
          if (localIdx != -1) {
            if ((fMovie.lastWatchedTimestamp ?? 0) > (_watchHistory[localIdx].lastWatchedTimestamp ?? 0)) {
              _watchHistory[localIdx] = fMovie;
            }
          } else {
            _watchHistory.add(fMovie);
          }
        }

        // Sắp xếp lại toàn bộ và giới hạn 20
        _watchHistory.sort((a, b) => (b.lastWatchedTimestamp ?? 0).compareTo(a.lastWatchedTimestamp ?? 0));
        if (_watchHistory.length > 20) {
          _watchHistory = _watchHistory.sublist(0, 20);
        }

        await _saveLocalHistory();
        notifyListeners();
      }
    } catch (e) {
      print("Lỗi syncHistoryFromFirebase: $e");
    }
  }

  // 3. Thêm/Cập nhật lịch sử (Local + Cloud)
  Future<void> addToHistory(Movie movie, {int? position, int? duration, String? epName}) async {
    movie.position = position ?? movie.position;
    movie.playbackDuration = duration ?? movie.playbackDuration;
    movie.episodeName = epName ?? movie.episodeName;
    movie.lastWatchedTimestamp = DateTime.now().millisecondsSinceEpoch;

    // Cập nhật Local
    _watchHistory.removeWhere((item) => item.slug == movie.slug);
    _watchHistory.insert(0, movie);
    if (_watchHistory.length > 20) _watchHistory = _watchHistory.sublist(0, 20);
    
    await _saveLocalHistory();
    notifyListeners();

    // Cập nhật Cloud (Firebase)
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _db.ref('watch_history/${user.uid}/${movie.slug}').set(movie.toJson());
      } catch (e) {
        print("Lỗi đẩy lịch sử lên Firebase: $e");
      }
    }
  }

  Future<void> _saveLocalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> encodeList = _watchHistory.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('watch_history', encodeList);
  }

  // Lấy dữ liệu xem tiếp cho một phim cụ thể
  Movie? getHistoryForMovie(String slug) {
    try {
      return _watchHistory.firstWhere((m) => m.slug == slug);
    } catch (_) {
      return null;
    }
  }

  // 4. Xóa toàn bộ lịch sử
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _watchHistory.clear();
    await prefs.remove('watch_history');
    
    final user = _auth.currentUser;
    if (user != null) {
      await _db.ref('watch_history/${user.uid}').remove();
    }

    notifyListeners();
  }
}