// lib/screens/user/category_movies_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Thêm import
import '../../models/movie.dart';
import '../../providers/movie_provider.dart'; // Thêm import
import '../../services/movie_service.dart';
import '../../widgets/movie_card.dart';

class CategoryMoviesScreen extends StatefulWidget {
  final String categoryName;
  final String categorySlug;
  final bool isCountry; // Thêm biến để phân biệt Thể loại hay Quốc gia

  const CategoryMoviesScreen({
    super.key,
    required this.categoryName,
    required this.categorySlug,
    this.isCountry = false,
  });

  @override
  State<CategoryMoviesScreen> createState() => _CategoryMoviesScreenState();
}

class _CategoryMoviesScreenState extends State<CategoryMoviesScreen> {
  final MovieService _movieService = MovieService();
  List<Movie> _movies = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadCategoryMovies();
  }

  Future<void> _loadCategoryMovies() async {
    setState(() => _isLoading = true);
    
    Map<String, dynamic> result;
    if (widget.isCountry) {
      result = await _movieService.fetchMoviesByCountry(widget.categorySlug, _currentPage);
    } else {
      result = await _movieService.fetchMoviesByCategory(widget.categorySlug, _currentPage);
    }

    // LỌC PHIM ẨN
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    final filteredMovies = movieProvider.filterHiddenMovies(result['movies'] ?? []);

    setState(() {
      _movies = filteredMovies;
      _totalPages = result['totalPages'] ?? 1;
      _isLoading = false;
    });
  }

  void _goToPage(int page) {
    if (page != _currentPage && page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPage = page;
      });
      _loadCategoryMovies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadCategoryMovies,
                    color: Colors.red,
                    child: _movies.isEmpty
                        ? const Center(
                            child: Text(
                              "Không có phim thuộc thể loại này.",
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.65,
                            ),
                            itemCount: _movies.length,
                            itemBuilder: (context, index) {
                              return MovieCard(movie: _movies[index]);
                            },
                          ),
                  ),
                ),
                // Thanh điều hướng trang số
                _buildPagination(),
              ],
            ),
    );
  }

  Widget _buildPagination() {
    List<Widget> pageButtons = [];
    
    // Nút Trang trước
    pageButtons.add(
      IconButton(
        icon: const Icon(Icons.chevron_left, color: Colors.white),
        onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
      ),
    );

    // Tính toán dải trang hiển thị (ví dụ: hiển thị 5 trang quanh trang hiện tại)
    int startPage = _currentPage - 2;
    int endPage = _currentPage + 2;

    if (startPage < 1) {
      endPage = endPage + (1 - startPage);
      startPage = 1;
    }
    if (endPage > _totalPages) {
      startPage = startPage - (endPage - _totalPages);
      endPage = _totalPages;
    }
    if (startPage < 1) startPage = 1;

    // Nút trang đầu nếu cần
    if (startPage > 1) {
      pageButtons.add(_buildPageButton(1));
      if (startPage > 2) {
        pageButtons.add(const Text("...", style: TextStyle(color: Colors.white)));
      }
    }

    // Các số trang trong dải
    for (int i = startPage; i <= endPage; i++) {
      pageButtons.add(_buildPageButton(i));
    }

    // Nút trang cuối nếu cần
    if (endPage < _totalPages) {
      if (endPage < _totalPages - 1) {
        pageButtons.add(const Text("...", style: TextStyle(color: Colors.white)));
      }
      pageButtons.add(_buildPageButton(_totalPages));
    }

    // Nút Trang sau
    pageButtons.add(
      IconButton(
        icon: const Icon(Icons.chevron_right, color: Colors.white),
        onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF1A1A1A),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: pageButtons,
        ),
      ),
    );
  }

  Widget _buildPageButton(int page) {
    bool isCurrent = page == _currentPage;
    return GestureDetector(
      onTap: () => _goToPage(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.red : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isCurrent ? null : Border.all(color: Colors.grey.shade800),
        ),
        child: Text(
          page.toString(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
