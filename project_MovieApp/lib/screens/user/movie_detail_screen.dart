import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/movie.dart';
import '../../providers/movie_provider.dart';
import '../user/player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Tải thông tin chi tiết phim ngay khi vào màn hình bằng slug
    Future.microtask(() =>
        Provider.of<MovieProvider>(context, listen: false)
            .loadMovieDetail(widget.movie.slug));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<MovieProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingDetail) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }

          final movieInfo = provider.movieDetailData;
          if (movieInfo == null) {
            return const Center(child: Text("Không thể tải thông tin bộ phim này."));
          }

          final categories = movieInfo['category'] as List? ?? [];
          final genres = categories.map((c) => c['name']).join(', ');

          return CustomScrollView(
            slivers: [
              // Banner header cuộn mượt mà
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: const Color(0xFF181818),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        movieInfo['poster_url'] ?? widget.movie.posterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.network(
                          widget.movie.thumbUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Toàn bộ khối thông tin chi tiết bên dưới banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên phim và nút thích
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              movieInfo['name'] ?? widget.movie.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              // Gọi hàm toggle thêm/xóa phim
                              provider.toggleFavorite(widget.movie);

                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.isFavorite(widget.movie.slug)
                                        ? "Đã xóa khỏi danh sách yêu thích"
                                        : "Đã thêm vào danh sách yêu thích",
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            icon: Icon(
                              // Nếu phim đã thích thì hiện tim Đỏ đầy, chưa thích hiện tim viền Trắng
                              provider.isFavorite(widget.movie.slug) ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Năm + Thể loại
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${movieInfo['year'] ?? widget.movie.year}",
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              genres.isNotEmpty ? genres : "Đang cập nhật thể loại",
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tóm tắt nội dung phim
                      const Text(
                        "Mô tả phim",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        movieInfo['content'] != null
                            ? movieInfo['content'].replaceAll(RegExp(r'<[^>]*>'), '')
                            : "Không có mô tả cho bộ phim này.",
                        style: const TextStyle(color: Colors.grey, height: 1.4, fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      // Khu vực hiển thị danh sách tập phim công chiếu
                      const Text(
                        "Danh sách tập",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),

                      if (provider.episodes.isEmpty)
                        const Text("Đang cập nhật tập phim...", style: TextStyle(color: Colors.grey))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          primary: false,
                          padding: EdgeInsets.zero,
                          itemCount: provider.episodes.length,
                          itemBuilder: (context, sIndex) {
                            final server = provider.episodes[sIndex];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (provider.episodes.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                      "Server: ${server.serverName}",
                                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                GridView.builder(
                                  shrinkWrap: true,
                                  primary: false,
                                  padding: const EdgeInsets.only(bottom: 16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 2.2,
                                  ),
                                  itemCount: server.serverData.length,
                                  itemBuilder: (context, eIndex) {
                                    final episode = server.serverData[eIndex];
                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF282828),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: () {
                                        _playVideo(context, episode);
                                      },
                                      child: Text(
                                        episode.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Hàm xử lý tạm thời khi click vào tập phim
  void _playVideo(
      BuildContext context,
      EpisodeDoc episode,
      ) {

    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          videoUrl: episode.linkM3u8,
          title: episode.name,
        ),
      ),
    );
  }
}