import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../../models/movie.dart';
import '../../providers/movie_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/review_provider.dart';
import '../../models/review.dart';
import '../../constants/api_constants.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/movie_card.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;
  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isDescriptionExpanded = false;
  final Map<String, bool> _expandedReplies = {}; // Lưu trạng thái ẩn/hiện reply cho từng user review
  MovieProvider? _movieProvider;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _movieProvider = Provider.of<MovieProvider>(context, listen: false);
      _movieProvider!.loadMovieDetail(widget.movie.slug);
      Provider.of<ReviewProvider>(context, listen: false).fetchReviews(widget.movie.slug);

      // Kết nối MovieProvider vào PlayerProvider để đồng bộ progress
      context.read<PlayerProvider>().setMovieProvider(_movieProvider!);
    });
  }

  /// Gọi hàm này để cập nhật sở thích khi phim đã load xong đầy đủ metadata
  void _trackClickAffinity(Movie fullMovie) {
    RecommendationService().updateAffinityFromClick(fullMovie);
  }

  void _playEpisode(List<EpisodeServer> episodes, int svIdx, int epIdx) {
    if (episodes.isEmpty) {
      _showPlayError("Dữ liệu tập phim chưa sẵn sàng.");
      return;
    }

    // Nếu truyền svIdx = -1 và epIdx = -1, nghĩa là muốn Resume từ lịch sử
    if (svIdx == -1 && epIdx == -1) {
      final history = context.read<MovieProvider>().getHistoryForMovie(widget.movie.slug);
      if (history != null && history.episodeName != null) {
        bool found = false;
        for (int s = 0; s < episodes.length; s++) {
          for (int e = 0; e < episodes[s].serverData.length; e++) {
            if (episodes[s].serverData[e].name == history.episodeName) {
              svIdx = s;
              epIdx = e;
              found = true;
              break;
            }
          }
          if (found) break;
        }
      }
      
      // Nếu không tìm thấy trong lịch sử, mặc định về tập 1
      if (svIdx == -1) {
        svIdx = 0;
        epIdx = 0;
      }
    }

    if (svIdx < 0 || svIdx >= episodes.length) svIdx = 0;
    
    // Kiểm tra xem server hiện tại có dữ liệu không
    final currentServer = episodes[svIdx];
    if (epIdx < 0 || epIdx >= currentServer.serverData.length) {
      _showPlayError("Tập phim không tồn tại.");
      return;
    }

    final episode = currentServer.serverData[epIdx];
    if (episode.linkM3u8.isEmpty) {
      // Nếu tập này không có link, thử tìm link đầu tiên hợp lệ trong server này (fallback)
      bool found = false;
      for (int i = 0; i < currentServer.serverData.length; i++) {
        if (currentServer.serverData[i].linkM3u8.isNotEmpty) {
          _doPlayEpisode(episodes, svIdx, i);
          found = true;
          break;
        }
      }
      if (!found) _showPlayError("Không tìm thấy link phát hợp lệ cho server này.");
    } else {
      _doPlayEpisode(episodes, svIdx, epIdx);
    }
  }

  void _doPlayEpisode(List<EpisodeServer> episodes, int svIdx, int epIdx) {
    final episode = episodes[svIdx].serverData[epIdx];
    
    // Dùng movieDetail đầy đủ (sau loadMovieDetail) để có categories/actors cho recommendation
    final movieForPlayer = _movieProvider?.movieDetail ?? widget.movie;

    // Lấy thông tin xem tiếp từ lịch sử
    final history = context.read<MovieProvider>().getHistoryForMovie(movieForPlayer.slug);
    Duration? startAt;
    
    // Nếu cùng tập phim thì mới resume (hoặc tùy bạn muốn resume bất kể tập nào)
    if (history != null && history.episodeName == episode.name && history.position != null) {
      startAt = Duration(seconds: history.position!);
    }

    // Lưu vào lịch sử xem phim
    context.read<MovieProvider>().addToHistory(movieForPlayer, epName: episode.name);

    context.read<PlayerProvider>().setVideo(
          movieForPlayer,
          episode.linkM3u8,
          episode.name,
          epIdx: epIdx,
          svIdx: svIdx,
          startAt: startAt,
        );
  }

  void _showPlayError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<PlayerProvider>().closePlayer();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF0F0F0F),
        body: Consumer<MovieProvider>(
          builder: (context, provider, child) {
            if (provider.isLoadingDetail) {
              return const Center(child: CircularProgressIndicator(color: Colors.amber));
            }

            final movie = provider.movieDetail;
            if (movie == null) {
              return const Center(
                  child: Text("Lỗi tải thông tin", style: TextStyle(color: Colors.white)));
            }

            // TRIGGER: Chỉ cộng điểm khi đã load xong phim đầy đủ categories/actors
            _trackClickAffinity(movie);

            return Column(
              children: [
                // HEADER AREA
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      children: [
                        if (player.currentMovie?.slug == widget.movie.slug &&
                            player.chewieController != null)
                          Positioned.fill(
                            child: Chewie(controller: player.chewieController!),
                          )
                        else
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                ApiConstants.getImageUrl(movie.thumbUrl),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[900],
                                  child: const Icon(Icons.movie, color: Colors.white24, size: 50),
                                ),
                              ),
                              Container(color: Colors.black26),
                              Center(
                                child: IconButton(
                                  icon: const Icon(Icons.play_circle_fill,
                                      color: Colors.amber, size: 64),
                                  onPressed: () => _playEpisode(provider.episodes, -1, -1), // Resume từ lịch sử
                                ),
                              ),
                            ],
                          ),
                        Positioned(
                          top: topPadding > 0 ? topPadding : 20,
                          left: 10,
                          child: CircleAvatar(
                            backgroundColor: Colors.black45,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        Positioned(
                          top: topPadding > 0 ? topPadding : 20,
                          right: 10,
                          child: Consumer<MovieProvider>(
                            builder: (context, movieProv, _) {
                              final isFav = movieProv.isFavorite(widget.movie.slug);
                              return CircleAvatar(
                                backgroundColor: Colors.black45,
                                child: IconButton(
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.red : Colors.white,
                                  ),
                                  onPressed: () {
                                    movieProv.toggleFavorite(widget.movie);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isFav ? "Đã xóa khỏi yêu thích" : "Đã thêm vào yêu thích"),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // CONTENT AREA
                Expanded(
                  child: Consumer<ReviewProvider>(
                    builder: (context, reviewProvider, child) {
                      return DefaultTabController(
                        length: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _buildMovieInfo(movie, provider.episodes, player),
                            ),
                            TabBar(
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              indicatorColor: Colors.amber,
                              indicatorSize: TabBarIndicatorSize.label,
                              labelColor: Colors.amber,
                              unselectedLabelColor: Colors.grey,
                              tabs: [
                                const Tab(text: "Giới thiệu"),
                                const Tab(text: "Tập phim"),
                                Tab(text: "Đánh giá (${reviewProvider.reviews.length})"),
                                const Tab(text: "Liên quan"),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildOverviewTab(movie),
                                  _buildEpisodesTab(provider, player),
                                  _buildReviewsTab(reviewProvider),
                                  _buildRelatedTab(provider),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMovieInfo(Movie movie, List<EpisodeServer> episodes, PlayerProvider player) {
    final bool isPlayingThis = player.currentMovie?.slug == widget.movie.slug;
    
    // Lấy tên tập hiện tại: ưu tiên tập đang phát, sau đó đến lịch sử, cuối cùng là "1"
    String currentEpName = "1";
    if (isPlayingThis) {
      currentEpName = player.currentEpisodeName ?? "1";
    } else {
      final history = context.read<MovieProvider>().getHistoryForMovie(widget.movie.slug);
      if (history != null && history.episodeName != null) {
        currentEpName = history.episodeName!;
      }
    }

    final genreNames = movie.categoryNames.values.join(', ');
    final primaryGenre = genreNames.split(',').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                movie.name,
                style:
                    const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration:
                  BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
              child: Text(
                "${currentEpName.startsWith('Tập') ? currentEpName : "Tập $currentEpName"}/${movie.episodeTotal ?? '???'}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Consumer<ReviewProvider>(
              builder: (context, revProv, _) {
                // Nhân 2 để chuyển từ thang 5 sao sang thang điểm 10
                final double score10 = revProv.averageRating * 2;
                final displayRating = revProv.reviews.isEmpty ? "0.0" : score10.toStringAsFixed(1);
                return Text(
                  "$displayRating/10",
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
                "${movie.year}  •  $primaryGenre  •  ${movie.durationLabel ?? '45 phút'}",
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: (isPlayingThis && player.currentEpisodeIndex > 0)
                    ? () => _playEpisode(
                        episodes, player.currentServerIndex, player.currentEpisodeIndex - 1)
                    : null,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("← Tập trước", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  int nextIdx = 0;
                  int svIdx = 0;

                  if (isPlayingThis) {
                    nextIdx = player.currentEpisodeIndex + 1;
                    svIdx = player.currentServerIndex;
                  } else {
                    // Nếu chưa phát, tìm tập tiếp theo dựa trên lịch sử
                    final history = context.read<MovieProvider>().getHistoryForMovie(widget.movie.slug);
                    if (history != null && history.episodeName != null) {
                      bool found = false;
                      for (int s = 0; s < episodes.length; s++) {
                        for (int e = 0; e < episodes[s].serverData.length; e++) {
                          if (episodes[s].serverData[e].name == history.episodeName) {
                            svIdx = s;
                            nextIdx = e + 1;
                            found = true;
                            break;
                          }
                        }
                        if (found) break;
                      }
                    } else {
                      // Nếu không có lịch sử, nút này đóng vai trò Play tập 1
                      nextIdx = 0;
                      svIdx = 0;
                    }
                  }
                  
                  if (nextIdx < episodes[svIdx].serverData.length) {
                    _playEpisode(episodes, svIdx, nextIdx);
                  } else {
                    _showPlayError("Đã đến tập cuối cùng.");
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("Tập tiếp →",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewTab(Movie movie) {
    final String content = movie.content?.replaceAll(RegExp(r'<[^>]*>'), '') ?? "Không có mô tả.";
    final String actorsDisplay = movie.actors.isEmpty ? "Đang cập nhật" : movie.actors.join(', ');
    final String directorsDisplay = movie.directors.isEmpty ? "Đang cập nhật" : movie.directors.join(', ');
    final String episodeDisplay = "${movie.episodeTotal ?? '??'} tập";
    final String viewDisplay = movie.viewCount != null && movie.viewCount! > 0
        ? "${_formatViewCount(movie.viewCount!)} lượt xem"
        : "";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content,
              maxLines: _isDescriptionExpanded ? null : 4,
              style: const TextStyle(color: Colors.white70, height: 1.5)),
          InkWell(
            onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
            child: Text(_isDescriptionExpanded ? "Thu gọn" : "Xem thêm...",
                style: const TextStyle(color: Colors.amber)),
          ),
          const SizedBox(height: 20),
          _buildDetailRow("Đạo diễn:", directorsDisplay),
          _buildDetailRow("Diễn viên:", actorsDisplay),
          _buildDetailRow("Số tập:", episodeDisplay),
          if (viewDisplay.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(viewDisplay,
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ],
      ),
    );
  }

  String _formatViewCount(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildEpisodesTab(MovieProvider provider, PlayerProvider player) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.episodes.length,
      itemBuilder: (context, sIdx) {
        final server = provider.episodes[sIdx];
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2),
          itemCount: server.serverData.length,
          itemBuilder: (context, eIdx) {
            final isPlaying = player.currentMovie?.slug == widget.movie.slug &&
                player.currentEpisodeIndex == eIdx &&
                player.currentServerIndex == sIdx;
            return GestureDetector(
              onTap: () => _playEpisode(provider.episodes, sIdx, eIdx),
              child: Container(
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.amber : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(server.serverData[eIdx].name,
                    style: TextStyle(
                        color: isPlaying ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRelatedTab(MovieProvider provider) {
    if (provider.relatedMovies.isEmpty) {
      return const Center(
          child: Text("Không có phim liên quan", style: TextStyle(color: Colors.white70)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: provider.relatedMovies.length,
      itemBuilder: (context, index) {
        return MovieCard(movie: provider.relatedMovies[index]);
      },
    );
  }

  Widget _buildReviewsTab(ReviewProvider reviewProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    // Tìm review của user hiện tại
    final myReview = user == null
        ? null
        : reviewProvider.reviews.firstWhere(
            (r) => r.userId == user.uid,
            orElse: () => Review(
                userId: '',
                userName: '',
                userEmail: '',
                rating: 0,
                comment: '',
                timestamp: 0),
          );

    final bool hasReviewed = myReview != null && myReview.userId.isNotEmpty;

    return Column(
      children: [
        if (user != null && !hasReviewed)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showReviewDialog(null),
              icon: const Icon(Icons.rate_review, color: Colors.black),
              label: const Text("Viết đánh giá của bạn",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        Expanded(
          child: reviewProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : reviewProvider.reviews.isEmpty
                  ? const Center(
                      child: Text("Chưa có đánh giá nào. Hãy là người đầu tiên!",
                          style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: reviewProvider.reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviewProvider.reviews[index];
                        final bool isMyReview = user != null && review.userId == user.uid;
                        return _buildReviewItem(review, isMyReview);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(Review review, bool isMyReview) {
    final date = DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(review.timestamp));
    final String firstLetter = review.userName.isNotEmpty ? review.userName[0].toUpperCase() : "?";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isMyReview ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: isMyReview ? Border.all(color: Colors.amber.withOpacity(0.3), width: 1) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.amber.withOpacity(0.2),
            child: Text(firstLetter, style: const TextStyle(color: Colors.amber)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(review.userName,
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ),
                    if (isMyReview)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                        color: const Color(0xFF2A2A2A),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _showReviewDialog(review);
                          } else if (value == 'delete') {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final user = authProvider.currentUser;
                            if (user != null) {
                              await Provider.of<ReviewProvider>(context, listen: false)
                                  .deleteReview(widget.movie.slug, user.uid);
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text("Sửa", style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                SizedBox(width: 8),
                                Text("Xóa", style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                if (isMyReview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(date, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
                const SizedBox(height: 4),
                RatingBarIndicator(
                  rating: review.rating,
                  itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber),
                  itemCount: 5,
                  itemSize: 14.0,
                  direction: Axis.horizontal,
                ),
                const SizedBox(height: 8),
                Text(review.comment, style: const TextStyle(color: Colors.white, height: 1.4)),
                const SizedBox(height: 12),
                
                // Nút Phản hồi
                GestureDetector(
                  onTap: () => _showReplyDialog(review),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        review.replies.isEmpty ? "Phản hồi" : "${review.replies.length} phản hồi",
                        style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Danh sách Phản hồi (Replies)
                if (review.replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logic ẩn hiện: nếu > 2 thì cho phép thu gọn
                        ...(_expandedReplies[review.userId] == true
                                ? review.replies
                                : review.replies.take(2))
                            .map((reply) => _buildReplyItem(review, reply)),
                        
                        if (review.replies.length > 2)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 34),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _expandedReplies[review.userId] = !(_expandedReplies[review.userId] ?? false);
                                });
                              },
                              child: Text(
                                _expandedReplies[review.userId] == true
                                    ? "Thu gọn"
                                    : "Xem thêm ${review.replies.length - 2} phản hồi...",
                                style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(Review parentReview, Reply reply) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final bool isMyReply = user != null && reply.userId == user.uid;
    final date = DateFormat('dd/MM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(reply.timestamp));

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.amber.withOpacity(0.1),
            child: Text(
              reply.userName.isNotEmpty ? reply.userName[0].toUpperCase() : "?",
              style: const TextStyle(color: Colors.amber, fontSize: 10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(reply.userName,
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                    if (isMyReply)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 80),
                        color: const Color(0xFF2A2A2A),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _showReplyDialog(parentReview, existingReply: reply);
                          } else if (value == 'delete') {
                            await Provider.of<ReviewProvider>(context, listen: false)
                                .deleteReply(widget.movie.slug, parentReview.userId, reply.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            height: 35,
                            child: Text("Sửa", style: TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            height: 35,
                            child: Text("Xóa", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),
                        ],
                      )
                    else
                      Text(date, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(reply.text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(Review review, {Reply? existingReply}) {
    final commentController = TextEditingController(text: existingReply?.text ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                existingReply == null
                    ? "Phản hồi @${review.userName}"
                    : "Chỉnh sửa phản hồi",
                style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Viết phản hồi của bạn...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final user = authProvider.currentUser;
                
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Bạn cần đăng nhập để phản hồi!")),
                  );
                  return;
                }

                if (commentController.text.trim().isEmpty) return;

                try {
                  if (existingReply == null) {
                    // Thêm mới
                    await Provider.of<ReviewProvider>(context, listen: false).addReply(
                      movieSlug: widget.movie.slug,
                      reviewUserId: review.userId,
                      text: commentController.text,
                      user: user,
                    );
                  } else {
                    // Cập nhật
                    await Provider.of<ReviewProvider>(context, listen: false).updateReply(
                      movieSlug: widget.movie.slug,
                      reviewUserId: review.userId,
                      replyId: existingReply.id,
                      newText: commentController.text,
                    );
                  }
                  
                  if (!mounted) return;
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(existingReply == null ? "Gửi phản hồi" : "Cập nhật",
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(Review? existingReview) {
    double rating = existingReview?.rating ?? 5.0;
    final commentController = TextEditingController(text: existingReview?.comment ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(existingReview == null ? "Đánh giá phim" : "Chỉnh sửa đánh giá",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            RatingBar.builder(
              initialRating: rating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (val) => rating = val,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: commentController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Cảm nhận của bạn về phim...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final user = authProvider.currentUser;
                
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Bạn cần đăng nhập để đánh giá!")),
                  );
                  return;
                }

                try {
                  // Gọi Provider để gửi review
                  final movieProvider = Provider.of<MovieProvider>(context, listen: false);
                  await Provider.of<ReviewProvider>(context, listen: false).addOrUpdateReview(
                    movieSlug: widget.movie.slug,
                    rating: rating,
                    comment: commentController.text,
                    user: user,
                    movie: movieProvider.movieDetail ?? widget.movie,
                  );
                  
                  // Kiểm tra mounted trước khi dùng context để tránh lỗi
                  if (!mounted) return;
                  
                  Navigator.of(context).pop(); // Đóng bottom sheet
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Đã gửi đánh giá thành công!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  print("LỖI KHI NHẤN NÚT GỬI: $e");
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Lỗi: ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Gửi đánh giá",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            if (existingReview != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final user = authProvider.currentUser;
                  if (user == null) return;

                  try {
                    await Provider.of<ReviewProvider>(context, listen: false)
                        .deleteReview(widget.movie.slug, user.uid);
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Đã xóa đánh giá!")),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Lỗi khi xóa: $e"), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text("Xóa đánh giá", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
