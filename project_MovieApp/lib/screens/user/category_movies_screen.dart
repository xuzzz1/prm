// lib/screens/user/category_movies_screen.dart
import 'package:flutter/material.dart';
import '../../models/movie.dart';
import '../../services/movie_service.dart';
import '../../widgets/movie_card.dart';

class CategoryMoviesScreen extends StatefulWidget {
  final String categoryName;
  final String categorySlug;

  const CategoryMoviesScreen({
    super.key,
    required this.categoryName,
    required this.categorySlug,
  });

  @override
  State<CategoryMoviesScreen> createState() => _CategoryMoviesScreenState();
}

class _CategoryMoviesScreenState extends State<CategoryMoviesScreen> {
  final MovieService _movieService = MovieService();
  List<Movie> _movies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoryMovies();
  }

  void _loadCategoryMovies() async {
    final result = await _movieService.fetchMoviesByCategory(widget.categorySlug, 1);
    setState(() {
      _movies = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: const Color(0xFF181818),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _movies.isEmpty
          ? const Center(child: Text("Không có phim thuộc thể loại này."))
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.6,
        ),
        itemCount: _movies.length,
        itemBuilder: (context, index) {
          return MovieCard(movie: _movies[index]);
        },
      ),
    );
  }
}