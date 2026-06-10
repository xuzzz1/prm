import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';
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
      await _db.ref('recommendation_prefs/$userId').set(prefs.toJson());
    } catch (e) {
      print('Error saving recommendation prefs: $e');
    }
  }

  double _bump(double current, double delta) {
    return (current + delta).clamp(0.0, 1.0);
  }

  void _bumpInt(Map<String, int> map, String key, int delta) {
    map[key] = (map[key] ?? 0) + delta;
  }

  Future<void> updateAffinityFromWatch(Movie movie, double percentWatched) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await fetchOrCreatePreferences(user.uid);

    final categoryWeight = percentWatched >= 0.9 ? 0.5 : 0.3;
    final countryWeight = categoryWeight * 0.7;
    final actorWeight = 0.2;

    final updatedCategoryAffinity = Map<String, double>.from(prefs.categoryAffinity);
    final updatedCountryAffinity = Map<String, double>.from(prefs.countryAffinity);
    final updatedActorAffinity = Map<String, double>.from(prefs.actorAffinity);
    final updatedWatchCount = Map<String, int>.from(prefs.watchCountByCategory);
    final updatedRecentSlugs = List<String>.from(prefs.recentWatchedSlugs);

    for (var cat in movie.categories) {
      updatedCategoryAffinity[cat] = _bump(updatedCategoryAffinity[cat] ?? 0, categoryWeight);
      _bumpInt(updatedWatchCount, cat, 1);
    }

    for (var country in movie.countries) {
      updatedCountryAffinity[country] = _bump(updatedCountryAffinity[country] ?? 0, countryWeight);
    }

    final topActors = movie.actors.take(3);
    for (var actor in topActors) {
      updatedActorAffinity[actor] = _bump(updatedActorAffinity[actor] ?? 0, actorWeight);
    }

    if (!updatedRecentSlugs.contains(movie.slug)) {
      updatedRecentSlugs.insert(0, movie.slug);
      if (updatedRecentSlugs.length > 20) {
        updatedRecentSlugs.removeLast();
      }
    }

    final updatedPrefs = prefs.copyWith(
      categoryAffinity: updatedCategoryAffinity,
      countryAffinity: updatedCountryAffinity,
      actorAffinity: updatedActorAffinity,
      watchCountByCategory: updatedWatchCount,
      totalMoviesWatched: prefs.totalMoviesWatched + 1,
      recentWatchedSlugs: updatedRecentSlugs,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
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
}
