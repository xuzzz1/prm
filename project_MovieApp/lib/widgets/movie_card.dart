import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../constants/api_constants.dart';
import '../providers/movie_provider.dart';
import '../screens/user/movie_detail_screen.dart'; // Import trang chi tiết vừa tạo

class MovieCard extends StatelessWidget {
  final Movie movie;

  const MovieCard({
    super.key,
    required this.movie,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        // Nhấn vào thẻ phim để chuyển tiếp sang trang chi tiết
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailScreen(movie: movie),
          ),
        );
      },
      child: Container(
        width: screenWidth * 0.38,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      ApiConstants.getImageUrl(movie.thumbUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.movie, color: Colors.white54),
                      ),
                    ),
                  ),
                  // Nút Trái tim bên ngoài MovieCard
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Consumer<MovieProvider>(
                      builder: (context, movieProv, _) {
                        final isFav = movieProv.isFavorite(movie.slug);
                        return GestureDetector(
                          onTap: () {
                            movieProv.toggleFavorite(movie);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isFav ? "Đã xóa khỏi yêu thích" : "Đã thêm vào yêu thích"),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : Colors.white,
                              size: 18,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              movie.year.toString(),
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}