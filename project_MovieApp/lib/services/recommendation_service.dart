import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';
import '../models/scored_movie.dart';
import '../models/recommendation_preference.dart';

class RecommendationService {
  // Singleton pattern to persist cache across widget rebuilds
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RecommendationPreference? _cachedPrefs;

  Future<RecommendationPreference?> get currentPrefs async {
    final user = _auth.currentUser;
    if (user == null) {
      _cachedPrefs = null;
      return null;
    }
    // Check if cache exists and belongs to the current user
    if (_cachedPrefs != null && _cachedPrefs!.userId == user.uid) {
      return _cachedPrefs;
    }
    return await fetchOrCreatePreferences(user.uid);
  }

  Future<RecommendationPreference> fetchOrCreatePreferences(String userId) async {
    try {
      final snapshot = await _db.ref('recommendation_prefs/$userId').get();
      if (snapshot.exists) {
        _cachedPrefs = RecommendationPreference.fromJson(
          Map<String, dynamic>.from(snapshot.value as Map),
          userId,
        );
        return _cachedPrefs!;
      }
    } catch (_) {
      // Non-critical; Firebase preferences are optional
    }

    // If not found in DB, return empty but check cache one last time
    if (_cachedPrefs != null && _cachedPrefs!.userId == userId) {
      return _cachedPrefs!;
    }

    _cachedPrefs = RecommendationPreference.empty(userId);
    await _savePreferences(userId, _cachedPrefs!);
    return _cachedPrefs!;
  }

  Future<void> _savePreferences(String userId, RecommendationPreference prefs) async {
    try {
      final json = prefs.toJson();
      await _db.ref('recommendation_prefs/$userId').set(json);
    } catch (_) {
      // Non-critical; Firebase preferences are optional
    }
  }

  double _bump(double current, double delta) {
    return (current + delta).clamp(0.0, 1.0);
  }

  /// Làm giảm nhẹ tất cả các điểm sở thích hiện có để nhường chỗ cho sở thích mới
  Map<String, double> _decay(Map<String, double> currentAffinities, {double factor = 0.9}) {
    final updated = <String, double>{};
    currentAffinities.forEach((key, value) {
      // Giảm 10% điểm (factor = 0.9). Nếu điểm quá thấp (< 0.05) thì xóa luôn để lọc bớt rác
      final newValue = value * factor;
      if (newValue > 0.05) {
        updated[key] = (newValue * 100).floorToDouble() / 100;
      }
    });
    return updated;
  }

  Future<void> updateAffinityFromWatch(Movie movie, double percentWatched) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await fetchOrCreatePreferences(user.uid);
    final isFirstWatch = !prefs.watchedSlugs.contains(movie.slug);

    final updatedRecentSlugs = List<String>.from(prefs.recentWatchedSlugs);
    if (!updatedRecentSlugs.contains(movie.slug)) {
      updatedRecentSlugs.insert(0, movie.slug);
      if (updatedRecentSlugs.length > 20) {
        updatedRecentSlugs.removeLast();
      }
    }

    // Only bump affinities once per unique movie (tracked permanently in watchedSlugs)
    if (!isFirstWatch) {
      final updatedCache = Map<String, Map<String, dynamic>>.from(prefs.watchedMoviesCache);
      updatedCache[movie.slug] = movie.toJson();
      final updatedPrefs = prefs.copyWith(
        recentWatchedSlugs: updatedRecentSlugs,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        watchedMoviesCache: updatedCache,
      );
      _cachedPrefs = updatedPrefs;
      await _savePreferences(user.uid, updatedPrefs);
      return;
    }

    final updatedWatchedSlugs = List<String>.from(prefs.watchedSlugs)..add(movie.slug);
    final updatedWatchedMoviesCache = Map<String, Map<String, dynamic>>.from(prefs.watchedMoviesCache);
    updatedWatchedMoviesCache[movie.slug] = movie.toJson();

    // ÁP DỤNG DECAY: Giảm điểm tất cả trước khi cộng cho phim này
    final updatedCategoryAffinity = _decay(Map<String, double>.from(prefs.categoryAffinity));
    final updatedCountryAffinity = _decay(Map<String, double>.from(prefs.countryAffinity));
    final updatedActorAffinity = _decay(Map<String, double>.from(prefs.actorAffinity));

    // TĂNG ĐỘ NHẠY: Chỉ cần xem 1 chút (percentWatched > 0) là đã cộng điểm đáng kể
    final baseBoost = percentWatched > 0.01 ? 0.3 : 0.1;
    final categoryWeight = ((percentWatched * 0.4 + baseBoost) * 10).floorToDouble() / 10;
    final countryWeight  = ((percentWatched * 0.2 + baseBoost * 0.5) * 10).floorToDouble() / 10;
    final actorWeight    = ((percentWatched * 0.2 + baseBoost * 0.5) * 10).floorToDouble() / 10;

    for (var cat in movie.categories) {
      updatedCategoryAffinity[cat] = _bump(updatedCategoryAffinity[cat] ?? 0, categoryWeight);
    }

    for (var country in movie.countries) {
      updatedCountryAffinity[country] = _bump(updatedCountryAffinity[country] ?? 0, countryWeight);
    }

    for (var actor in movie.actors.take(3)) {
      updatedActorAffinity[actor] = _bump(updatedActorAffinity[actor] ?? 0, actorWeight);
    }

    final updatedPrefs = prefs.copyWith(
      categoryAffinity: updatedCategoryAffinity,
      countryAffinity: updatedCountryAffinity,
      actorAffinity: updatedActorAffinity,
      watchedSlugs: updatedWatchedSlugs,
      totalMoviesWatched: prefs.totalMoviesWatched + 1,
      recentWatchedSlugs: updatedRecentSlugs,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      watchedMoviesCache: updatedWatchedMoviesCache,
    );

    _cachedPrefs = updatedPrefs;
    await _savePreferences(user.uid, updatedPrefs);
  }

  Future<void> updateAffinityFromFavorite(Movie movie, bool isAdding) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await fetchOrCreatePreferences(user.uid);

    final weight = isAdding ? 0.5 : -0.3;

    final updatedCategoryAffinity = Map<String, double>.from(prefs.categoryAffinity);
    final updatedFavoriteSlugs = List<String>.from(prefs.favoriteSlugs);

    for (var cat in movie.categories) {
      updatedCategoryAffinity[cat] = _bump(updatedCategoryAffinity[cat] ?? 0, weight);
    }

    if (isAdding) {
      if (!updatedFavoriteSlugs.contains(movie.slug)) {
        updatedFavoriteSlugs.insert(0, movie.slug);
      }
    } else {
      updatedFavoriteSlugs.remove(movie.slug);
    }

    final updatedPrefs = prefs.copyWith(
      categoryAffinity: updatedCategoryAffinity,
      favoriteSlugs: updatedFavoriteSlugs,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    _cachedPrefs = updatedPrefs;
    await _savePreferences(user.uid, updatedPrefs);
  }

  Future<void> updateAffinityFromRating(Movie movie, double rating) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await fetchOrCreatePreferences(user.uid);

    double weight;
    if (rating >= 5.0) {
      weight = 1.0;
    } else if (rating >= 4.0) {
      weight = 0.7;
    } else if (rating >= 3.0) {
      weight = 0.3;
    } else {
      weight = -0.3;
    }

    final updatedCategoryAffinity = Map<String, double>.from(prefs.categoryAffinity);
    final updatedCountryAffinity = Map<String, double>.from(prefs.countryAffinity);
    final updatedActorAffinity = Map<String, double>.from(prefs.actorAffinity);

    for (var cat in movie.categories) {
      updatedCategoryAffinity[cat] = _bump(updatedCategoryAffinity[cat] ?? 0, weight);
    }

    for (var country in movie.countries) {
      updatedCountryAffinity[country] = _bump(updatedCountryAffinity[country] ?? 0, weight * 0.7);
    }

    for (var actor in movie.actors.take(3)) {
      updatedActorAffinity[actor] = _bump(updatedActorAffinity[actor] ?? 0, weight * 0.5);
    }

    final updatedRecentSlugs = List<String>.from(prefs.recentWatchedSlugs);
    if (!updatedRecentSlugs.contains(movie.slug)) {
      updatedRecentSlugs.insert(0, movie.slug);
      if (updatedRecentSlugs.length > 20) updatedRecentSlugs.removeLast();
    }
    
    final updatedCache = Map<String, Map<String, dynamic>>.from(prefs.watchedMoviesCache);
    updatedCache[movie.slug] = movie.toJson();

    final updatedPrefs = prefs.copyWith(
      categoryAffinity: updatedCategoryAffinity,
      countryAffinity: updatedCountryAffinity,
      actorAffinity: updatedActorAffinity,
      recentWatchedSlugs: updatedRecentSlugs,
      watchedMoviesCache: updatedCache,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    _cachedPrefs = updatedPrefs;
    await _savePreferences(user.uid, updatedPrefs);
  }

  Future<void> updateAffinityFromSearch(String query) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final lowerQuery = query.toLowerCase();

    final knownGenres = {
      'hanh dong': 'hanh-dong',
      'hành động': 'hanh-dong',
      'action': 'hanh-dong',
      'tinh cam': 'tinh-cam',
      'tình cảm': 'tinh-cam',
      'romance': 'tinh-cam',
      'hai huoc': 'hai-huoc',
      'hài hước': 'hai-huoc',
      'comedy': 'hai-huoc',
      'vien tuong': 'vien-tuong',
      'viễn tưởng': 'vien-tuong',
      'sci-fi': 'vien-tuong',
      'science fiction': 'vien-tuong',
      'kinh di': 'kinh-di',
      'kinh dị': 'kinh-di',
      'horror': 'kinh-di',
      'chinh kich': 'chinh-kich',
      'chính kịch': 'chinh-kich',
      'drama': 'chinh-kich',
      'co trang': 'co-trang',
      'cổ trang': 'co-trang',
      'historical': 'co-trang',
      'hoat hinh': 'hoat-hinh',
      'hoạt hình': 'hoat-hinh',
      'anime': 'hoat-hinh',
      'cartoon': 'hoat-hinh',
      'phim bo': 'phim-bo',
      'series': 'phim-bo',
      'phim le': 'phim-le',
      'single': 'phim-le',
      'movie': 'phim-le',
    };

    for (var entry in knownGenres.entries) {
      if (lowerQuery.contains(entry.key)) {
        await _bumpCategory(entry.value, 0.2);
        return;
      }
    }
  }

  Future<void> _bumpCategory(String categorySlug, double weight) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await fetchOrCreatePreferences(user.uid);
    final updated = Map<String, double>.from(prefs.categoryAffinity);
    updated[categorySlug] = _bump(updated[categorySlug] ?? 0, weight);

    final updatedPrefs = prefs.copyWith(
      categoryAffinity: updated,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    _cachedPrefs = updatedPrefs;
    await _savePreferences(user.uid, updatedPrefs);
  }

  /// Cập nhật sở thích ngay khi người dùng CLICK vào xem chi tiết phim
  Future<void> updateAffinityFromClick(Movie movie) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await fetchOrCreatePreferences(user.uid);
    
    // Nếu đã xem rồi thì không cộng điểm click nữa để tránh spam
    if (prefs.watchedSlugs.contains(movie.slug)) return;

    final weight = 0.4; // Tăng mạnh điểm để demo giáo viên thấy ngay sự thay đổi khi click

    // ÁP DỤNG DECAY: Mỗi lần click phim mới, sở thích cũ sẽ bị mờ nhạt đi 10%
    final updatedCategoryAffinity = _decay(Map<String, double>.from(prefs.categoryAffinity));
    final updatedCountryAffinity = _decay(Map<String, double>.from(prefs.countryAffinity));
    final updatedActorAffinity = _decay(Map<String, double>.from(prefs.actorAffinity));

    for (var cat in movie.categories) {
      updatedCategoryAffinity[cat] = _bump(updatedCategoryAffinity[cat] ?? 0, weight);
    }
    for (var country in movie.countries) {
      updatedCountryAffinity[country] = _bump(updatedCountryAffinity[country] ?? 0, weight * 0.5);
    }
    for (var actor in movie.actors.take(3)) {
      updatedActorAffinity[actor] = _bump(updatedActorAffinity[actor] ?? 0, weight * 0.5);
    }

    final updatedRecentSlugs = List<String>.from(prefs.recentWatchedSlugs);
    if (!updatedRecentSlugs.contains(movie.slug)) {
      updatedRecentSlugs.insert(0, movie.slug);
      if (updatedRecentSlugs.length > 20) updatedRecentSlugs.removeLast();
    }
    
    final updatedCache = Map<String, Map<String, dynamic>>.from(prefs.watchedMoviesCache);
    updatedCache[movie.slug] = movie.toJson();

    final updatedPrefs = prefs.copyWith(
      categoryAffinity: updatedCategoryAffinity,
      countryAffinity: updatedCountryAffinity,
      actorAffinity: updatedActorAffinity,
      watchedSlugs: List<String>.from(prefs.watchedSlugs)..add(movie.slug),
      recentWatchedSlugs: updatedRecentSlugs,
      watchedMoviesCache: updatedCache,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    _cachedPrefs = updatedPrefs;
    await _savePreferences(user.uid, updatedPrefs);
  }

  void invalidateCache() {
    _cachedPrefs = null;
  }

  // Scoring helpers — used by Phase 2 scoring engine
  double _softmax(double raw, {double k = 0.3}) {
    return raw / (raw + k);
  }

  double _avgCategoryAffinity(Movie movie, RecommendationPreference prefs) {
    if (movie.categories.isEmpty) return 0;
    double sum = 0;
    for (var cat in movie.categories) {
      sum += prefs.categoryAffinity[cat] ?? 0;
    }
    return sum / movie.categories.length;
  }

  double _avgCountryAffinity(Movie movie, RecommendationPreference prefs) {
    if (movie.countries.isEmpty) return 0;
    double sum = 0;
    for (var country in movie.countries) {
      sum += prefs.countryAffinity[country] ?? 0;
    }
    return sum / movie.countries.length;
  }

  double _actorScore(Movie movie, RecommendationPreference prefs) {
    if (movie.actors.isEmpty) return 0;
    final topActors = movie.actors.take(5).toList();
    double sum = 0;
    for (var actor in topActors) {
      sum += prefs.actorAffinity[actor] ?? 0;
    }
    return _softmax(sum / topActors.length.clamp(1, 5));
  }

  double _freshnessScore(Movie movie) {
    final currentYear = DateTime.now().year;
    final age = currentYear - movie.year;
    if (age <= 0) return 1.0;
    if (age <= 2) return 0.8;
    if (age <= 5) return 0.5;
    return 0.2;
  }

  ScoredMovie scoreMovie(Movie movie, RecommendationPreference prefs, {double trendingWeight = 0.0}) {
    final category = _avgCategoryAffinity(movie, prefs);
    final country = _avgCountryAffinity(movie, prefs);
    final actors = _actorScore(movie, prefs);
    final freshness = _freshnessScore(movie);

    // TĂNG TRỌNG SỐ 
    final contentScore = (category * 0.6) + (country * 0.2) + (actors * 0.2);
    
    // Content giờ chiếm 85%, Freshness chỉ chiếm 5%, Trending 10%
    final totalScore = (contentScore * 0.85) + (freshness * 0.05) + (trendingWeight * 0.1);

    final reason = _generateMatchReason(movie, prefs, category, actors);

    return ScoredMovie(
      movie: movie,
      totalScore: totalScore,
      contentScore: contentScore,
      affinityScore: category,
      actorScore: actors,
      trendingScore: trendingWeight,
      freshnessScore: freshness,
      matchReason: reason,
    );
  }

  Future<List<ScoredMovie>> scoreMovies(List<Movie> movies, {double trendingWeight = 0.0}) async {
    final prefs = await currentPrefs;
    if (prefs == null || (prefs.watchedSlugs.isEmpty && prefs.favoriteSlugs.isEmpty && prefs.categoryAffinity.isEmpty)) {
      // NEW USER LOGIC: Show high-quality movies with generic labels
      return movies.map((m) => ScoredMovie(
        movie: m,
        totalScore: 0,
        contentScore: 0,
        affinityScore: 0,
        actorScore: 0,
        trendingScore: 0,
        freshnessScore: _freshnessScore(m),
        matchReason: m.year >= DateTime.now().year - 1 ? 'Phim mới' : 'Gợi ý cho bạn',
      )).toList();
    }

    final watchedSet = prefs.watchedSlugs.toSet();
    final unwatched = movies.where((m) => !watchedSet.contains(m.slug)).toList();

    final pool = unwatched.isEmpty ? movies : unwatched;
    final scored = pool.map((m) => scoreMovie(m, prefs, trendingWeight: trendingWeight)).toList();
    
    // EXISTING USER LOGIC: Filter out movies that have NO interest match
    // Only keep movies where there is at least some affinity or actor score
    final personalizedScored = scored.where((sm) => sm.affinityScore > 0 || sm.actorScore > 0).toList();
    
    // If we have personalized results, sort and return them
    if (personalizedScored.isNotEmpty) {
      personalizedScored.sort((a, b) => b.totalScore.compareTo(a.totalScore));
      return personalizedScored;
    }
    
    // Fallback if no specific match found, but still try to show movies related to the categories of the history
    scored.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return scored;
  }

  String _generateMatchReason(Movie movie, RecommendationPreference prefs, double affinity, double actors) {
    final reasons = <String>[];

    // 1. Tìm thể loại trùng khớp có điểm sở thích CAO NHẤT (không lấy bừa cái đầu tiên)
    String? bestCat;
    double maxStrength = 0;
    
    for (var cat in movie.categories) {
      final strength = prefs.categoryAffinity[cat] ?? 0;
      if (strength > maxStrength && strength > 0.4) {
        maxStrength = strength;
        bestCat = cat;
      }
    }

    if (bestCat != null) {
      reasons.add('Phim ${_formatCategory(bestCat)}');
    }

    // 2. Ưu tiên diễn viên yêu thích (> 0.3) nếu chưa có lý do thể loại mạnh
    if (reasons.isEmpty) {
      for (var actor in movie.actors.take(3)) {
        final strength = prefs.actorAffinity[actor] ?? 0;
        if (strength > 0.3) {
          reasons.add('Thích phim của $actor');
          break;
        }
      }
    }

    // 3. Nếu chưa có lý do từ sở thích cụ thể, hiện thể loại đầu tiên của phim
    if (reasons.isEmpty && movie.categoryNames.isNotEmpty) {
      reasons.add(movie.categoryNames.values.first);
    }

    // 4. Cuối cùng mới là các nhãn mặc định (Chỉ hiện cho người dùng chưa có lịch sử)
    if (reasons.isEmpty) {
      final isNewUser = prefs.watchedSlugs.isEmpty && prefs.favoriteSlugs.isEmpty;
      if (isNewUser) {
        if (movie.year >= DateTime.now().year - 1) {
          reasons.add('Phim mới cập nhật');
        } else {
          reasons.add('Gợi ý cho bạn');
        }
      } else {
        // Nếu đã xem phim rồi, hiện thể loại đầu tiên thay vì nhãn chung chung
        if (movie.categoryNames.isNotEmpty) {
           reasons.add(movie.categoryNames.values.first);
        } else {
           reasons.add('Dành cho bạn');
        }
      }
    }

    return reasons.join(' • ');
  }

  String _formatCategory(String slug) {
    switch (slug) {
      case 'hanh-dong': return 'Hành Động';
      case 'tinh-cam': return 'Tình Cảm';
      case 'hai-huoc': return 'Hài Hước';
      case 'vien-tuong': return 'Viễn Tưởng';
      case 'kinh-di': return 'Kinh Dị';
      case 'chinh-kich': return 'Chính Kịch';
      case 'co-trang': return 'Cổ Trang';
      case 'hoat-hinh': return 'Hoạt Hình';
      case 'phim-bo': return 'Phim Bộ';
      case 'phim-le': return 'Phim Lẻ';
      case 'tam-ly': return 'Tâm Lý';
      case 'hinh-su': return 'Hình Sự';
      case 'am-nhac': return 'Âm Nhạc';
      case 'tai-lieu': return 'Tài Liệu';
      case 'kinh-dong': return 'Kinh Đông';
      case 'tv-show': return 'TV Show';
      case 'thieu-nhi': return 'Thiếu Nhi';
      case 'gia-dinh': return 'Gia Đình';
      case 'khoa-hoc': return 'Khoa Học';
      case 'chien-tranh': return 'Chiến Tranh';
      case 'vo-thuat': return 'Võ Thuật';
      case 'than-thoai': return 'Thần Thoại';
      case 'sieu-nhân': return 'Siêu Nhân';
      case 'ma-am': return 'Ma Ám';
      case 'bi-an': return 'Bí Ẩn';
      case 'lang-mang': return 'Lang Mạng';
      case 'phim-nuoc-ngoai': return 'Phim Nước Ngoài';
      case 'phim-chieu-rap': return 'Phim Chiếu Rạp';
      case 'hành-trình': return 'Hành Trình';
      case 'bí-ẩn': return 'Bí Ẩn';
      default: return slug.replaceAll('-', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }
  }

  /// Scores and sorts a pool of movies by totalScore (descending), then returns
  /// the top [limit]. Used by "Vì bạn đã xem phim X" to pick similar movies.
  Future<List<ScoredMovie>> scoreMoviesForSeed(List<Movie> pool, int limit, {double trendingWeight = 0.0}) async {
    final scored = await scoreMovies(pool, trendingWeight: trendingWeight);
    return scored.take(limit).toList();
  }

  /// Returns the single best "Because you watched [Movie]" section.
  /// Picks the watched movie with the highest affinity-overlap score.
  Future<MovieBasedSection?> getTopWatchedMovie(List<Movie> allMovies) async {
    final prefs = await currentPrefs;
    if (prefs == null || prefs.recentWatchedSlugs.isEmpty) return null;

    final combinedAffinity = <String, double>{};
    for (var e in prefs.categoryAffinity.entries) {
      combinedAffinity[e.key] = e.value * 1.0;
    }
    for (var e in prefs.countryAffinity.entries) {
      combinedAffinity[e.key] = (combinedAffinity[e.key] ?? 0) + (e.value * 0.8);
    }
    for (var e in prefs.actorAffinity.entries) {
      combinedAffinity[e.key] = (combinedAffinity[e.key] ?? 0) + (e.value * 0.5);
    }

    Movie? bestMovie;
    double bestScore = 0;

    for (var slug in prefs.recentWatchedSlugs.take(20)) {
      final cached = prefs.watchedMoviesCache[slug];
      if (cached == null) continue;

      final movie = Movie.fromJson(cached);
      double movieScore = 0;

      for (var cat in movie.categories) {
        movieScore += combinedAffinity[cat] ?? 0;
      }
      for (var country in movie.countries) {
        movieScore += combinedAffinity[country] ?? 0;
      }
      for (var actor in movie.actors.take(3)) {
        movieScore += combinedAffinity[actor] ?? 0;
      }

      if (movieScore > bestScore) {
        bestScore = movieScore;
        bestMovie = movie;
      }
    }

    if (bestMovie == null || bestScore < 0.1) return null;

    return MovieBasedSection(
      seedMovie: bestMovie,
      reason: 'Vì bạn đã xem phim ${bestMovie.name}',
    );
  }
}

class MovieBasedSection {
  final Movie seedMovie;
  final String reason;

  MovieBasedSection({required this.seedMovie, required this.reason});
}
