import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../constants/api_constants.dart';
import '../providers/movie_provider.dart';
import '../screens/user/movie_detail_screen.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final double width;
  final String? matchReason;

  const MovieCard({
    super.key,
    required this.movie,
    this.width = 120,
    this.matchReason,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailScreen(movie: movie),
          ),
        );
      },
      child: Container(
        width: width,
        // Tạo bo góc và đổ bóng cho cả thẻ
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 0.65, // Tỉ lệ poster chuẩn
            child: Stack(
              children: [
                // 1. Lớp Nền: Ảnh Poster
                Positioned.fill(
                  child: Image.network(
                    ApiConstants.getImageUrl(movie.thumbUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.movie, color: Colors.white24, size: 40),
                    ),
                  ),
                ),

                // 2. Lớp Phủ: Gradient đen mờ để nổi bật chữ
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.95),
                        ],
                        stops: const [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Lớp Chữ: Thông tin phim nằm đè lên ảnh
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        movie.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        matchReason ?? movie.year.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: matchReason != null ? Colors.amber : Colors.grey[400],
                          fontSize: 10,
                          fontWeight: matchReason != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Lớp Tương tác: Nút Yêu thích
                Positioned(
                  top: 6,
                  right: 6,
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
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : Colors.white,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
