// lib/screens/user/home_screen.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart'; // Thêm dòng này
import '../../services/movie_service.dart';
import '../../services/recommendation_service.dart';
import '../../models/movie.dart';
import '../../models/scored_movie.dart';
import '../../providers/movie_provider.dart';
import '../../widgets/movie_card.dart';
import '../../constants/api_constants.dart';
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
    return Scaffold(
      appBar: _currentIndex == 0 
          ? AppBar(
        backgroundColor: const Color(0xFF181818),
        title: const Text("Movie App", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
            icon: const Icon(Icons.search),
          ),
        ],
      )
          : null, 

      // SỬ DỤNG IndexedStack để giữ trạng thái các Tab, không load lại khi chuyển
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
        backgroundColor: const Color(0xFF181818),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; 
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: "Category"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favorite"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// Tách phần Body của Home ra một Widget riêng và dùng AutomaticKeepAliveClientMixin
class _HomeTabBody extends StatefulWidget {
  const _HomeTabBody();

  @override
  State<_HomeTabBody> createState() => _HomeTabBodyState();
}

class _HomeTabBodyState extends State<_HomeTabBody> with AutomaticKeepAliveClientMixin {
  final MovieService movieService = MovieService();
  final RecommendationService recommendationService = RecommendationService();
  List<Movie> movies = [];
  List<Movie> trendingMovies = [];
  List<Movie> bannerMovies = []; // Thêm danh sách phim cho Banner
  List<ScoredMovie> recommendedMovies = [];
  bool isLoading = true;
  bool isRecommendedLoading = true;

  MovieBasedSection? _movieBasedSection;
  List<ScoredMovie> _movieBasedMovies = [];
  int _refreshCounter = 0; // Bộ đếm để reset hoàn toàn UI các danh sách khi Refresh

  @override
  bool get wantKeepAlive => true; // GIỮ TRẠNG THÁI: Không load lại khi chuyển tab

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await fetchMovies();
    await Future.wait([
      _loadBannerMovies(), // Tải phim Banner
      _loadRecommendations(),
      _loadMovieBasedSection(),
    ]);
  }

  Future<void> _loadBannerMovies() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('settings/banners').get();
      if (snapshot.exists) {
        final List<dynamic> slugs = snapshot.value as List<dynamic>;
        
        // Gọi API lấy chi tiết từng phim trong banner
        final List<Movie> loadedBanners = [];
        for (var slug in slugs) {
          final result = await movieService.fetchMovieDetail(slug.toString());
          if (result != null && result['movie'] != null) {
            loadedBanners.add(Movie.fromJson(result['movie']));
          }
        }
        
        if (mounted) {
          setState(() {
            bannerMovies = loadedBanners;
          });
        }
      }
    } catch (e) {
      print("Lỗi load banner: $e");
    }
  }

  Future<void> fetchMovies() async {
    // 1. Tải cả phim bộ và phim lẻ mới nhất để trộn
    final results = await Future.wait([
      movieService.fetchMoviesByType('phim-bo', 1),
      movieService.fetchMoviesByType('phim-le', 1),
      movieService.fetchMoviesByType('phim-bo', 2), // Lấy thêm để lọc được nhiều phim 2024-2025 hơn
      movieService.fetchMoviesByType('phim-le', 2),
    ]);

    List<Movie> allNew = [];
    for (var res in results) {
      if (res['movies'] != null) {
        allNew.addAll(res['movies'] as List<Movie>);
      }
    }

    // 2. LỌC CHỈ LẤY PHIM THỰC SỰ MỚI (Năm 2024 - 2025)
    final currentYear = DateTime.now().year;
    final trulyNewMovies = allNew.where((m) => m.year >= currentYear - 1).toList();
    
    // Sắp xếp: Phim 2025 lên đầu, rồi đến 2024
    trulyNewMovies.sort((a, b) => b.year.compareTo(a.year));

    // 3. Tải Trending (Lấy từ trang khác hoặc danh sách hoạt hình/viễn tưởng để đa dạng)
    final trendingRes = await movieService.fetchMoviesByType('hoat-hinh', 1);
    final List<Movie> trendingList = trendingRes['movies'] ?? [];

    if (!mounted) return;

    setState(() {
      movies = trulyNewMovies.isNotEmpty ? trulyNewMovies : allNew.take(15).toList();
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

  Future<void> _loadRecommendations() async {
    final prefs = await recommendationService.currentPrefs;
    List<Movie> pool = [];

    // 1. LẤY PHIM THEO THỂ LOẠI YÊU THÍCH (Dùng trực tiếp API thể loại)
    if (prefs != null && prefs.categoryAffinity.isNotEmpty) {
      var sortedCats = prefs.categoryAffinity.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      // Lấy phim từ TOP 4 thể loại
      final topSlugs = sortedCats.take(4).map((e) => e.key).toList();
      
      // ĐẶC BIỆT: Luôn lấy thêm thể loại của bộ phim vừa tương tác gần nhất 
      // để đảm bảo Recommend thay đổi ngay lập tức theo hành động của user
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
      
      final catResults = await Future.wait(
        topSlugs.take(6).map((slug) => movieService.fetchMoviesByCategory(slug, 1))
      );

      for (var res in catResults) {
        if (res['movies'] != null) pool.addAll(res['movies'] as List<Movie>);
      }
    }

    // 2. Nếu kho phim vẫn ít hoặc rỗng, lấy thêm phim mới để đa dạng
    if (pool.length < 15) {
      final results = await Future.wait([
        movieService.fetchMoviesByType('phim-bo', 1),
        movieService.fetchMoviesByType('phim-le', 1),
      ]);
      for (var res in results) {
        if (res['movies'] != null) pool.addAll(res['movies'] as List<Movie>);
      }
    }

    final result = await recommendationService.scoreMovies(pool);
    
    // FIX: Lọc bỏ những phim đã xuất hiện trong mục "New Movies" (biến movies)
    final newMoviesSlugs = movies.map((m) => m.slug).toSet();
    final filteredResult = result.where((sm) => !newMoviesSlugs.contains(sm.movie.slug)).take(15).toList();

    if (!mounted) return;
    setState(() {
      recommendedMovies = filteredResult;
      isRecommendedLoading = false;
    });
  }

  Future<void> _handleRefresh() async {
    // Reset toàn bộ trạng thái để hiện loading full màn hình như lúc mới vào
    setState(() {
      _refreshCounter++; // Tăng bộ đếm để đổi Key cho tất cả danh sách
      isLoading = true;
      isRecommendedLoading = true;
    });

    // Tải lại toàn bộ dữ liệu theo đúng thứ tự
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    return Material(
      color: Colors.black,
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Colors.red,
              backgroundColor: Colors.black,
              child: Consumer<MovieProvider>(
                builder: (context, movieProvider, child) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(), // Đảm bảo luôn có thể vuốt để refresh
                    key: const PageStorageKey('home_scroll'), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const SizedBox(height: 12),
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 200,
                        autoPlay: true,
                        enlargeCenterPage: true,
                      ),
                      items: () {
                        // 1. Lấy danh sách phim Admin chọn
                        List<Movie> displayBanners = List.from(bannerMovies);
                        
                        // 2. Nếu chưa đủ 5 phim, lấy thêm từ danh sách phim mới để lấp đầy
                        if (displayBanners.length < 5) {
                          // Lấy các phim mới mà chưa có trong danh sách banner của admin
                          final adminSlugs = displayBanners.map((m) => m.slug).toSet();
                          final fillerMovies = movies.where((m) => !adminSlugs.contains(m.slug)).take(5 - displayBanners.length);
                          displayBanners.addAll(fillerMovies);
                        }
                        
                        // Trả về tối đa 5 phim (hoặc nhiều hơn nếu admin chọn nhiều hơn)
                        return displayBanners.take(displayBanners.length > 5 ? displayBanners.length : 5).map((movie) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(20),
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
                      const SizedBox(height: 16),
                      _buildSectionTitle("Continue Watching"),
                      _buildContinueWatchingList(movieProvider.watchHistory),
                    ],
                    if (_movieBasedSection != null && _movieBasedMovies.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle(_movieBasedSection!.seedMovie.name, subtitle: _movieBasedSection!.reason),
                      _buildMovieBasedHorizontalList(_movieBasedMovies),
                    ],
                    const SizedBox(height: 16),
                    _buildSectionTitle("New Movies"),
                    _buildMovieHorizontalList(movies),
                    _buildSectionTitle("Recommend"),
                    isRecommendedLoading
                        ? const SizedBox(
                            height: 180,
                            child: Center(child: CircularProgressIndicator(color: Colors.amber)),
                          )
                        : _buildRecommendedHorizontalList(),
                    _buildSectionTitle("Trending"),
                    _buildMovieHorizontalList(trendingMovies),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
      )
    );
    
  }

  Widget _buildContinueWatchingList(List<Movie> history) {
    return SizedBox(
      height: 235, // Giảm từ 260 xuống để khít với nội dung hơn
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.builder(
          key: ValueKey("continue_watching_$_refreshCounter"),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final movie = history[index];
            final progress = movie.playbackDuration != null && movie.playbackDuration! > 0
                ? (movie.position ?? 0) / movie.playbackDuration!
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Giới hạn kích thước column
                children: [
                  MovieCard(movie: movie),
                  const SizedBox(height: 8),
                  if (movie.episodeName != null)
                    SizedBox(
                      width: 120,
                      child: Text(
                        movie.episodeName!.toLowerCase().contains('tập') 
                            ? movie.episodeName! 
                            : "Tập ${movie.episodeName}",
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                      minHeight: 2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMovieHorizontalList(List<Movie> movieList) {
    return SizedBox(
      height: 200,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.builder(
          key: ValueKey("movie_list_${movieList.hashCode}_$_refreshCounter"),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: movieList.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: MovieCard(movie: movieList[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Giảm từ 12 xuống 8
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.amber[300], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMovieBasedHorizontalList(List<ScoredMovie> sectionMovies) {
    return SizedBox(
      height: 200,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.builder(
          key: ValueKey("movie_based_$_refreshCounter"),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: sectionMovies.length,
          itemBuilder: (context, index) {
            final scored = sectionMovies[index];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: MovieCard(movie: scored.movie, matchReason: scored.matchReason),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecommendedHorizontalList() {
    return SizedBox(
      height: 200,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.builder(
          key: ValueKey("recommended_$_refreshCounter"),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: recommendedMovies.length,
          itemBuilder: (context, index) {
            final scored = recommendedMovies[index];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: MovieCard(movie: scored.movie, matchReason: scored.matchReason),
            );
          },
        ),
      ),
    );
  }
}
