// lib/screens/user/home_screen.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/gestures.dart';
import '../../services/movie_service.dart';
import '../../models/movie.dart';
import '../../widgets/movie_card.dart';
import '../../constants/api_constants.dart';
import '../../widgets/movie_search.dart';
import 'category_screen.dart'; // Import Màn hình thể loại mới làm
import 'favorite_screen.dart';
import 'profile_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MovieService movieService = MovieService();
  List<Movie> movies = [];
  bool isLoading = true;

  // Quản lý tab hiện tại của Bottom Navigation
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchMovies();
  }

  Future<void> fetchMovies() async {
    final result = await movieService.fetchTrendingMovies();
    setState(() {
      movies = result;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tạo danh sách các Body màn hình tương ứng với các tab dưới Bottom Bar
    final List<Widget> _screens = [
      _buildHomeBody(),         // Tab 0: Home chính
      const CategoryScreen(),   // Tab 1: Màn hình Thể loại vừa hoàn thành
      const FavoriteScreen(), // Tab 2
      const ProfileScreen(),  // Tab 3
    ];

    return Scaffold(
      appBar: _currentIndex == 0 // Chỉ hiện AppBar chung ở màn hình Trang chủ chính
          ? AppBar(
        backgroundColor: const Color(0xFF181818),
        title: const Text("Movie App", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () {
              showSearch(context: context, delegate: MovieSearch());
            },
            icon: const Icon(Icons.search),
          ),
        ],
      )
          : null, // Các màn hình phụ tự quản lý AppBar riêng của nó

      body: _screens[_currentIndex], // Đổi nội dung hiển thị theo tab được chọn

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF181818),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Cập nhật lại vị trí tab khi click chọn
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

  // Chuyển toàn bộ Body giao diện trang chủ cũ của bạn vào hàm widget này
  Widget _buildHomeBody() {
    return isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.red))
        : SingleChildScrollView(
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
            items: movies.take(5).map((movie) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  ApiConstants.getImageUrl(movie.thumbUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("New Movies"),
          _buildMovieHorizontalList(),
          _buildSectionTitle("Recommend"),
          _buildMovieHorizontalList(),
          _buildSectionTitle("Trending"),
          _buildMovieHorizontalList(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildMovieHorizontalList() {
    return SizedBox(
      height: 230,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.builder(
          primary: false,
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: movies.length,
          itemBuilder: (context, index) {
            return MovieCard(movie: movies[index]);
          },
        ),
      ),
    );
  }
}