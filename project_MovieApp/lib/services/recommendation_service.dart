import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';
import '../models/scored_movie.dart';
import '../models/recommendation_preference.dart';

class RecommendationService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RecommendationPreference? _cachedPrefs;

  Future<RecommendationPreference?> get currentPrefs async {
    final user = _auth.currentUser;
    if (user == null) return null;
    if (_cachedPrefs != null) return _cachedPrefs;
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
    } catch (e) {
      print('Error loading recommendation prefs: $e');
    }

    _cachedPrefs = RecommendationPreference.empty(userId);
    await _savePreferences(userId, _cachedPrefs!);
    return _cachedPrefs!;
  }

  Future<void> _savePreferences(String userId, RecommendationPreference prefs) async {
    try {
      final json = prefs.toJson();
      await _db.ref('recommendation_prefs/$userId').set(json);
    } catch (e, stack) {
      print('[RecommendationService] Error saving prefs: $e\n$stack');
    }
  }

  double _bump(double current, double delta) {
    return (current + delta).clamp(0.0, 1.0);
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

    final categoryWeight = ((percentWatched * 0.2) * 10).floorToDouble() / 10;
    final countryWeight  = ((percentWatched * 0.2) * 10).floorToDouble() / 10;
    final actorWeight    = ((percentWatched * 0.2) * 10).floorToDouble() / 10;

    final updatedCategoryAffinity = Map<String, double>.from(prefs.categoryAffinity);
    final updatedCountryAffinity = Map<String, double>.from(prefs.countryAffinity);
    final updatedActorAffinity = Map<String, double>.from(prefs.actorAffinity);
    final updatedWatchedSlugs = List<String>.from(prefs.watchedSlugs)..add(movie.slug);
    final updatedWatchedMoviesCache = Map<String, Map<String, dynamic>>.from(prefs.watchedMoviesCache);
    updatedWatchedMoviesCache[movie.slug] = movie.toJson();

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

    final updatedPrefs = prefs.copyWith(
      categoryAffinity: updatedCategoryAffinity,
      countryAffinity: updatedCountryAffinity,
      actorAffinity: updatedActorAffinity,
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
    final affinity = _avgCategoryAffinity(movie, prefs);
    final country = _avgCountryAffinity(movie, prefs);
    final actors = _actorScore(movie, prefs);
    final freshness = _freshnessScore(movie);

    final contentScore = (affinity * 0.5) + (country * 0.25) + (actors * 0.25);

    final totalScore = (contentScore * 0.7) + (freshness * 0.2) + (trendingWeight * 0.1);

    final reason = _generateMatchReason(movie, prefs, affinity, actors);

    return ScoredMovie(
      movie: movie,
      totalScore: totalScore,
      contentScore: contentScore,
      affinityScore: affinity,
      actorScore: actors,
      trendingScore: trendingWeight,
      freshnessScore: freshness,
      matchReason: reason,
    );
  }

  Future<List<ScoredMovie>> scoreMovies(List<Movie> movies, {double trendingWeight = 0.0}) async {
    final prefs = await currentPrefs;
    if (prefs == null) {
      return movies.map((m) => ScoredMovie(
        movie: m,
        totalScore: 0,
        contentScore: 0,
        affinityScore: 0,
        actorScore: 0,
        trendingScore: 0,
        freshnessScore: _freshnessScore(m),
        matchReason: 'Vì bạn mới tham gia',
      )).toList();
    }

    final watchedSet = prefs.watchedSlugs.toSet();
    final unwatched = movies.where((m) => !watchedSet.contains(m.slug)).toList();

    // Fall back to full list if too few unwatched movies remain
    final pool = unwatched.length < 5 ? movies : unwatched;
    final scored = pool.map((m) => scoreMovie(m, prefs, trendingWeight: trendingWeight)).toList();
    scored.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return scored;
  }

  String _generateMatchReason(Movie movie, RecommendationPreference prefs, double affinity, double actors) {
    final reasons = <String>[];

    for (var cat in movie.categories) {
      final strength = prefs.categoryAffinity[cat] ?? 0;
      if (strength > 0.5) {
        reasons.add('Yêu thích ${_formatCategory(cat)}');
        break;
      }
    }

    for (var actor in movie.actors.take(3)) {
      final strength = prefs.actorAffinity[actor] ?? 0;
      if (strength > 0.3) {
        reasons.add('Thích phim của $actor');
        break;
      }
    }

    if (movie.year >= DateTime.now().year - 1) {
      reasons.add('Phim mới');
    }

    if (reasons.isEmpty) {
      if (affinity > 0.3) {
        reasons.add('Phù hợp sở thích');
      } else if (movie.year >= DateTime.now().year - 3) {
        reasons.add('Phim mới');
      } else {
        reasons.add('Phổ biến');
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
      case 'phim-sex': return 'Phim Sex';
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
