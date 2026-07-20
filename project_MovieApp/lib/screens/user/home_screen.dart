// lib/screens/user/home_screen.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import '../../services/movie_service.dart';
import '../../services/recommendation_service.dart';
import '../../models/movie.dart';
import '../../models/scored_movie.dart';
import '../../providers/movie_provider.dart';
import '../../widgets/movie_card.dart';
import '../../constants/api_constants.dart';
import '../../themes/app_theme.dart';
import '../../main.dart' show snackBarKey;
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
  List<Movie> trendingMovies = [];
  List<Movie> bannerMovies = [];
  List<Movie> recentlyUpdatedMovies = [];
  List<ScoredMovie> recommendedMovies = [];
  bool isLoading = true;
  bool isRecommendedLoading = true;

  MovieBasedSection? _movieBasedSection;
  List<ScoredMovie> _movieBasedMovies = [];
  ActorBasedSection? _actorBasedSection;
  int _refreshCounter = 0;

  /// Shared pool populated by Phase 2 enrichment. Used by recommendations and
  /// movie-based sections for scoring without re-fetching.
  List<Movie> _homePool = [];

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

  /// Phase 1: fetch 10 list pages and set the sorted sections immediately.
  /// This makes banner/trending/recent appear without waiting for detail fetches.
  Future<void> _initializeData() async {
    try {
      final cached = await movieService.getCachedHomeResult();
      if (cached != null) {
        setState(() {
          bannerMovies = cached.bannerMovies;
          trendingMovies = cached.trendingMovies;
          recentlyUpdatedMovies = cached.recentlyUpdatedMovies;
          isLoading = false;
        });
        _loadEnrichedPool(cached.allMovies);
        return;
      }

      final quickResult = await movieService.fetchMoviesForHomeQuick(pages: 10);
      if (!mounted) return;

      setState(() {
        bannerMovies = quickResult.bannerMovies;
        trendingMovies = quickResult.trendingMovies;
        recentlyUpdatedMovies = quickResult.recentlyUpdatedMovies;
        isLoading = false;
      });

      _loadEnrichedPool(quickResult.allMovies);
    } catch (e) {
      if (!mounted) return;
      snackBarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Không thể tải dữ liệu: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() => isLoading = false);
    }
  }

  /// Phase 2: detail-enrich the already-fetched [pool], then update recommendations
  /// and movie-based sections in the background.
  Future<void> _loadEnrichedPool(List<Movie> pool) async {
    _homePool = pool;
    _loadRecommendations();
    _loadMovieBasedSection();
    _loadActorBasedSection();

    try {
      final allMovies = await movieService.fetchMoviesForHomeEnriched(pool: pool);
      if (!mounted) return;
      setState(() => _homePool = allMovies);
    } catch (_) {
      // Enrichment is best-effort; keep pool from Phase 1
    }
  }

  Future<void> _loadMovieBasedSection() async {
    if (_homePool.isEmpty) return;
    final movieBased = await recommendationService.getTopWatchedMovie(_homePool);
    if (movieBased != null) {
      final similar = await recommendationService.scoreMoviesForSeed(_homePool, 12);
      if (!mounted) return;
      setState(() {
        _movieBasedSection = movieBased;
        _movieBasedMovies = similar;
      });
    }
  }

  Future<void> _loadActorBasedSection() async {
    if (_homePool.isEmpty) return;
    final actorSection = await recommendationService.getTopActorSection(_homePool, limit: 12);
    print('[DEBUG] ActorBasedSection: $actorSection');
    if (!mounted) return;
    setState(() {
      _actorBasedSection = actorSection;
    });
  }

  Future<void> _refreshRecommendations() async {
    recommendationService.invalidateCache();
    final prefs = await recommendationService.currentPrefs;
    if (prefs == null || prefs.categoryAffinity.isEmpty) return;
    setState(() => _refreshCounter++);
    await Future.wait([
      Future(() async {
        await _loadRecommendations();
      }),
      Future(() async {
        await _loadMovieBasedSection();
      }),
      Future(() async {
        await _loadActorBasedSection();
      }),
    ]);
  }

  Future<void> _loadRecommendations() async {
    if (_homePool.isEmpty) return;
    final result = await recommendationService.scoreMovies(_homePool);
    final bannerSlugs = bannerMovies.map((m) => m.slug).toSet();
    final filteredResult = result
        .where((sm) => !bannerSlugs.contains(sm.movie.slug))
        .take(15)
        .toList();

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
                        final fillerMovies = _homePool.where((m) => !adminSlugs.contains(m.slug)).take(5 - displayBanners.length);
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
                  if (_actorBasedSection != null && _actorBasedSection!.movies.isNotEmpty) ...[
                    SizedBox(height: _debugActorSection(_actorBasedSection!)),
                    _buildSectionTitle('Phim của ${_actorBasedSection!.actorName}', subtitle: 'Vì bạn thích diễn viên này'),
                    _buildMovieBasedHorizontalList(_actorBasedSection!.movies),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionTitle("Recently Updated"),
                  _buildMovieHorizontalList(recentlyUpdatedMovies),
                  const SizedBox(height: 24),
                  // _buildSectionTitle("Recommend"),
                  // isRecommendedLoading
                  //     ? const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber)))
                  //     : _buildRecommendedHorizontalList(),
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

  double _debugActorSection(ActorBasedSection section) {
    print('[DEBUG BUILD] rendering actor section: ${section.actorName} with ${section.movies.length} movies');
    return 24;
  }
}
