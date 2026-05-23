// lib/widgets/movie_search.dart
import 'package:flutter/material.dart';
import '../services/movie_service.dart';
import '../models/movie.dart';
import 'movie_card.dart';

class MovieSearch extends SearchDelegate {
  final MovieService _movieService = MovieService();

  // Đổi màu chữ/nền thanh Search cho đồng bộ Dark Theme
  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => query = "",
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  // Khi người dùng bấm "Tìm kiếm" trên bàn phím
  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text("Vui lòng nhập từ khóa tìm kiếm"));
    }

    return FutureBuilder<List<Movie>>(
      future: _movieService.searchMovies(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.red));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Không tìm thấy bộ phim nào phù hợp"));
        }

        final results = snapshot.data!;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.6,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            return MovieCard(movie: results[index]);
          },
        );
      },
    );
  }

  // Gợi ý khi người dùng đang gõ chữ (Tận dụng gọi API trực tiếp để bắt kết quả)
  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().length < 2) {
      return const Center(child: Text("Nhập tối thiểu 2 ký tự để tìm kiếm"));
    }

    return FutureBuilder<List<Movie>>(
      future: _movieService.searchMovies(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final suggestions = snapshot.data!;

        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final movie = suggestions[index];
            return ListTile(
              leading: const Icon(Icons.movie_filter, color: Colors.grey),
              title: Text(movie.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(movie.year.toString(), style: const TextStyle(color: Colors.grey)),
              onTap: () {
                query = movie.name;
                showResults(context);
              },
            );
          },
        );
      },
    );
  }
}