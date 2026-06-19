// lib/screens/user/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/movie_provider.dart';
import '../../widgets/movie_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Lịch sử xem phim", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<MovieProvider>(
            builder: (context, provider, child) {
              if (provider.watchHistory.isEmpty) return const SizedBox();
              return TextButton(
                onPressed: () => _showClearDialog(context, provider),
                child: const Text("Xóa tất cả", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              );
            },
          ),
        ],
      ),
      body: Consumer<MovieProvider>(
        builder: (context, provider, child) {
          if (provider.watchHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  const Text(
                    "Lịch sử của bạn đang trống",
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
              mainAxisSpacing: 20,
              crossAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            itemCount: provider.watchHistory.length,
            itemBuilder: (context, index) {
              return MovieCard(movie: provider.watchHistory[index]);
            },
          );
        },
      ),
    );
  }

  void _showClearDialog(BuildContext context, MovieProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Xóa lịch sử", style: TextStyle(color: Colors.white)),
        content: const Text("Bạn có chắc chắn muốn xóa toàn bộ lịch sử xem phim không?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(context);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
