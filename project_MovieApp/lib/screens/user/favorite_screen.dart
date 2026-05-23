// lib/screens/user/favorite_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/movie_provider.dart';
import '../../widgets/movie_card.dart';

class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Phim Yêu Thích", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF181818),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<MovieProvider>(
        builder: (context, provider, child) {
          final favMovies = provider.favoriteMovies;

          if (favMovies.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Danh sách trống.\n Hãy thêm bộ phim bạn thích nhé!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.6,
            ),
            itemCount: favMovies.length,
            itemBuilder: (context, index) {
              return MovieCard(movie: favMovies[index]);
            },
          );
        },
      ),
    );
  }
}