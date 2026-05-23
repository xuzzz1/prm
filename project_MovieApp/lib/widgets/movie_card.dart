import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../constants/api_constants.dart';
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  ApiConstants.getImageUrl(movie.thumbUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.movie, color: Colors.white54),
                  ),
                ),
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