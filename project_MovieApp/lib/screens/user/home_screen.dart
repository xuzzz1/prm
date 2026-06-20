// lib/screens/user/home_screen.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/movie_service.dart';
import '../../services/recommendation_service.dart';
import '../../models/movie.dart';
import '../../models/scored_movie.dart';
import '../../providers/movie_provider.dart';
import '../../widgets/movie_card.dart';
import '../../constants/api_constants.dart';
import '../../themes/app_theme.dart';
import 'category_screen.dart'; 
import 'favorite_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.mainGradient,
        child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _currentIndex == 0
            ? AppBar(
          title: const Text("MOVIE APP", style: TextStyle(letterSpacing: 4)),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: 8),
          ],
        )
            : null,

        body: IndexedStack(
          index: _currentIndex,
          children: const [
            _HomeTabBody(),         
            CategoryScreen(),
            FavoriteScreen(),
            ProfileScreen(),
          ],
        ),

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.category_rounded), label: "Category"),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: "Favorite"),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
          ],
        ),
      ),
    );
  }
}

class _HomeTabBody extends StatefulWidget {
  const _HomeTabBody();

  @override
  State<_HomeTabBody> createState() => _HomeTabBodyState();
}

class _HomeTabBodyState extends State<_HomeTabBody> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final MovieService movieService = MovieService();
  final RecommendationService recommendationService = RecommendationService();
  List<Movie> movies = [];
  List<Movie> trendingMovies = [];
  List<Movie> bannerMovies = [];
  List<ScoredMovie> recommendedMovies = [];
  bool isLoading = true;
  bool isRecommendedLoading = true;

  MovieBasedSection? _movieBasedSection;
  List<ScoredMovie> _movieBasedMovies = [];
  int _refreshCounter = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !isRecommendedLoading) {
      recommendationService.invalidateCache();
      _refreshRecommendations();
    }
  }

  Future<void> _initializeData() async {
    await fetchMovies();
    await Future.wait([
      _loadBannerMovies(),
      _loadRecommendations(),
      _loadMovieBasedSection(),
    ]);
  }

  Future<void> _loadBannerMovies() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('settings/banners').get();
      if (snapshot.exists) {
        final List<dynamic> slugs = snapshot.value as List<dynamic>;
        final List<Movie> loadedBanners = [];
        for (var slug in slugs) {
          final result = await movieService.fetchMovieDetail(slug.toString());
          if (result != null && result['movie'] != null) {
            loadedBanners.add(Movie.fromJson(result['movie']));
          }
        }
        if (mounted) setState(() => bannerMovies = loadedBanners);
      }
    } catch (e) {
      debugPrint("Lỗi load banner: $e");
    }
  }

  Future<void> fetchMovies() async {
    final hiddenSnapshot = await FirebaseDatabase.instance.ref('settings/hidden_movies').get();
    final Set<String> hiddenSlugs = {};
    if (hiddenSnapshot.exists) {
      final Map<dynamic, dynamic> data = hiddenSnapshot.value as Map<dynamic, dynamic>;
      hiddenSlugs.addAll(data.keys.cast<String>());
    }

    final results = await Future.wait([
      movieService.fetchMoviesByType('phim-bo', 1),
      movieService.fetchMoviesByType('phim-le', 1),
      movieService.fetchMoviesByType('phim-bo', 2),
      movieService.fetchMoviesByType('phim-le', 2),
    ]);

    List<Movie> allNew = [];
    for (var res in results) {
      if (res['movies'] != null) allNew.addAll(res['movies'] as List<Movie>);
    }

    final currentYear = DateTime.now().year;
    final trulyNewMovies = allNew.where((m) => 
      m.year >= currentYear - 1 && !hiddenSlugs.contains(m.slug)
    ).toList();
    trulyNewMovies.sort((a, b) => b.year.compareTo(a.year));

    final trendingRes = await movieService.fetchMoviesByType('hoat-hinh', 1);
    final List<Movie> trendingList = (trendingRes['movies'] as List<Movie>?)
            ?.where((m) => !hiddenSlugs.contains(m.slug))
            .toList() ?? [];

    if (!mounted) return;
    setState(() {
      movies = trulyNewMovies.isNotEmpty ? trulyNewMovies : allNew.where((m) => !hiddenSlugs.contains(m.slug)).take(15).toList();
      trendingMovies = trendingList;
      isLoading = false;
    });
  }

  Future<void> _loadMovieBasedSection() async {
    final pool = await movieService.fetchAllMovies(pages: 3);
    final movieBased = await recommendationService.getTopWatchedMovie(pool);
    if (movieBased != null) {
      final similar = await recommendationService.scoreMoviesForSeed(pool, 12);
      if (!mounted) return;
      setState(() {
        _movieBasedSection = movieBased;
        _movieBasedMovies = similar;
      });
    }
  }

  Future<void> _refreshRecommendations() async {
    recommendationService.invalidateCache();
    final prefs = await recommendationService.currentPrefs;
    // Skip if nothing has changed since last load
    if (prefs == null || prefs.categoryAffinity.isEmpty) return;
    setState(() => _refreshCounter++);
    await Future.wait([
      _loadRecommendations(),
      _loadMovieBasedSection(),
    ]);
  }

  Future<void> _loadRecommendations() async {
    final prefs = await recommendationService.currentPrefs;
    Map<String, Movie> poolMap = {};

    if (prefs != null && prefs.categoryAffinity.isNotEmpty) {
      var sortedCats = prefs.categoryAffinity.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topSlugs = sortedCats.take(4).map((e) => e.key).toList();
      
      if (prefs.recentWatchedSlugs.isNotEmpty) {
        final lastSlug = prefs.recentWatchedSlugs.first;
        final lastMovieData = prefs.watchedMoviesCache[lastSlug];
        if (lastMovieData != null) {
          final lastMovie = Movie.fromJson(lastMovieData);
          for (var cat in lastMovie.categories) {
            if (!topSlugs.contains(cat)) topSlugs.add(cat);
          }
        }
      }
      
      final catResults = await Future.wait(topSlugs.take(6).map((slug) => movieService.fetchMoviesByCategory(slug, 1)));
      for (var res in catResults) {
        if (res['movies'] != null) {
          for (var m in (res['movies'] as List<Movie>)) {
            poolMap[m.slug] = m;
          }
        }
      }
    }

    if (poolMap.length < 15) {
      final results = await Future.wait([movieService.fetchMoviesByType('phim-bo', 1), movieService.fetchMoviesByType('phim-le', 1)]);
      for (var res in results) {
        if (res['movies'] != null) {
          for (var m in (res['movies'] as List<Movie>)) {
            poolMap[m.slug] = m;
          }
        }
      }
    }

    final pool = poolMap.values.toList();
    final result = await recommendationService.scoreMovies(pool);
    final newMoviesSlugs = movies.map((m) => m.slug).toSet();
    final filteredResult = result.where((sm) => !newMoviesSlugs.contains(sm.movie.slug)).take(15).toList();

    if (!mounted) return;
    setState(() {
      recommendedMovies = filteredResult;
      isRecommendedLoading = false;
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshCounter++;
      isLoading = true;
      isRecommendedLoading = true;
    });
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    return isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
        : RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppTheme.primaryAmber,
            backgroundColor: AppTheme.secondaryAnthracite,
            child: Consumer<MovieProvider>(
              builder: (context, movieProvider, child) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  key: const PageStorageKey('home_scroll'), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const SizedBox(height: 12),
                  CarouselSlider(
                    options: CarouselOptions(
                      height: 220,
                      autoPlay: true,
                      enlargeCenterPage: true,
                      enlargeFactor: 0.2,
                    ),
                    items: () {
                      List<Movie> displayBanners = List.from(bannerMovies);
                      if (displayBanners.length < 5) {
                        final adminSlugs = displayBanners.map((m) => m.slug).toSet();
                        final fillerMovies = movies.where((m) => !adminSlugs.contains(m.slug)).take(5 - displayBanners.length);
                        displayBanners.addAll(fillerMovies);
                      }
                      return displayBanners.take(5).map((movie) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            ApiConstants.getImageUrl(movie.thumbUrl),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        );
                      }).toList();
                    }(),
                  ),
                  if (movieProvider.watchHistory.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle("Continue Watching"),
                    _buildContinueWatchingList(movieProvider.watchHistory),
                  ],
                  if (_movieBasedSection != null && _movieBasedMovies.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle(_movieBasedSection!.seedMovie.name, subtitle: _movieBasedSection!.reason),
                    _buildMovieBasedHorizontalList(_movieBasedMovies),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionTitle("New Movies"),
                  _buildMovieHorizontalList(movies),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Recommend"),
                  isRecommendedLoading
                      ? const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber)))
                      : _buildRecommendedHorizontalList(),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Trending"),
                  _buildMovieHorizontalList(trendingMovies),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
    );
  }

  Widget _buildContinueWatchingList(List<Movie> history) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        key: ValueKey("continue_watching_$_refreshCounter"),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final movie = history[index];
          final progress = movie.playbackDuration != null && movie.playbackDuration! > 0
              ? (movie.position ?? 0) / movie.playbackDuration!
              : 0.0;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: MovieCard(movie: movie)),
                const SizedBox(height: 12),
                if (movie.episodeName != null)
                  SizedBox(
                    width: 120,
                    child: Text(
                      movie.episodeName!.toLowerCase().contains('tập') ? movie.episodeName! : "Tập ${movie.episodeName}",
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryAmber),
                      minHeight: 2,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovieHorizontalList(List<Movie> movieList) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        key: ValueKey("movie_list_${movieList.hashCode}_$_refreshCounter"),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: movieList.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: MovieCard(movie: movieList[index]),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppTheme.primaryAmber, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMovieBasedHorizontalList(List<ScoredMovie> sectionMovies) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        key: ValueKey("movie_based_$_refreshCounter"),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: sectionMovies.length,
        itemBuilder: (context, index) {
          final scored = sectionMovies[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: MovieCard(movie: scored.movie, matchReason: scored.matchReason),
          );
        },
      ),
    );
  }

  Widget _buildRecommendedHorizontalList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        key: ValueKey("recommended_$_refreshCounter"),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: recommendedMovies.length,
        itemBuilder: (context, index) {
          final scored = recommendedMovies[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: MovieCard(movie: scored.movie, matchReason: scored.matchReason),
          );
        },
      ),
    );
  }
}
