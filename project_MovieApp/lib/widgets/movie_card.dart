import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../screens/user/movie_detail_screen.dart';
import '../constants/api_constants.dart';
import '../themes/app_theme.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final String? matchReason;

  const MovieCard({super.key, required this.movie, this.matchReason});

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
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Hero(
                    tag: 'movie_${movie.slug}_${hashCode}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 120,
                        height: 180,
                        child: Image.network(
                          ApiConstants.getImageUrl(movie.thumbUrl),
                          fit: BoxFit.cover,
                          width: 120,
                          height: 180,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppTheme.secondaryAnthracite,
                            child: const Center(
                              child: Icon(Icons.movie_rounded, color: Colors.white24),
                            ),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: AppTheme.secondaryAnthracite,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryAmber,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // Màn chắn gradient nhẹ ở dưới để text dễ đọc
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Rating Badge hoặc Year
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAmber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        movie.year.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (matchReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  matchReason!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.primaryAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
