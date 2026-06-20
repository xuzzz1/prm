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
import '../../themes/app_theme.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;
  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isDescriptionExpanded = false;
  final Map<String, bool> _expandedReplies = {};
  MovieProvider? _movieProvider;

  // Track which slugs have already triggered affinity click to prevent double-fire
  final Set<String> _trackedClickSlugs = {};
  final RecommendationService _recommendationService = RecommendationService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _movieProvider = Provider.of<MovieProvider>(context, listen: false);
      _movieProvider!.loadMovieDetail(widget.movie.slug);
      Provider.of<ReviewProvider>(context, listen: false).fetchReviews(widget.movie.slug);
      context.read<PlayerProvider>().setMovieProvider(_movieProvider!);
    });
  }

  @override
  void didUpdateWidget(covariant MovieDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.slug != widget.movie.slug) {
      Future.microtask(() {
        _movieProvider = Provider.of<MovieProvider>(context, listen: false);
        _movieProvider!.loadMovieDetail(widget.movie.slug);
        Provider.of<ReviewProvider>(context, listen: false).fetchReviews(widget.movie.slug);
        context.read<PlayerProvider>().setMovieProvider(_movieProvider!);
      });
    }
  }

  void _trackClickAffinity(Movie fullMovie) {
    if (_trackedClickSlugs.contains(fullMovie.slug)) return;
    _trackedClickSlugs.add(fullMovie.slug);
    _recommendationService.updateAffinityFromClick(fullMovie);
  }

  void _onMovieDetailLoaded(Movie? movie) {
    if (movie != null) _trackClickAffinity(movie);
  }

  void _playEpisode(List<EpisodeServer> episodes, int svIdx, int epIdx) {
    if (episodes.isEmpty) {
      _showPlayError("Dữ liệu tập phim chưa sẵn sàng.");
      return;
    }
    if (svIdx == -1 && epIdx == -1) {
      final history = context.read<MovieProvider>().getHistoryForMovie(widget.movie.slug);
      if (history != null && history.episodeName != null) {
        bool found = false;
        for (int s = 0; s < episodes.length; s++) {
          for (int e = 0; e < episodes[s].serverData.length; e++) {
            if (episodes[s].serverData[e].name == history.episodeName) {
              svIdx = s; epIdx = e; found = true; break;
            }
          }
          if (found) break;
        }
      }
      if (svIdx == -1) { svIdx = 0; epIdx = 0; }
    }
    if (svIdx < 0 || svIdx >= episodes.length) svIdx = 0;
    final currentServer = episodes[svIdx];
    if (epIdx < 0 || epIdx >= currentServer.serverData.length) {
      _showPlayError("Tập phim không tồn tại.");
      return;
    }
    final episode = currentServer.serverData[epIdx];
    if (episode.linkM3u8.isEmpty) {
      bool found = false;
      for (int i = 0; i < currentServer.serverData.length; i++) {
        if (currentServer.serverData[i].linkM3u8.isNotEmpty) {
          _doPlayEpisode(episodes, svIdx, i); found = true; break;
        }
      }
      if (!found) _showPlayError("Không tìm thấy link phát hợp lệ.");
    } else {
      _doPlayEpisode(episodes, svIdx, epIdx);
    }
  }

  void _doPlayEpisode(List<EpisodeServer> episodes, int svIdx, int epIdx) {
    final episode = episodes[svIdx].serverData[epIdx];
    final movieForPlayer = _movieProvider?.movieDetail ?? widget.movie;
    final history = context.read<MovieProvider>().getHistoryForMovie(movieForPlayer.slug);
    Duration? startAt;
    if (history != null && history.episodeName == episode.name && history.position != null) {
      startAt = Duration(seconds: history.position!);
    }
    context.read<MovieProvider>().addToHistory(movieForPlayer, epName: episode.name);
    context.read<PlayerProvider>().setVideo(movieForPlayer, episode.linkM3u8, episode.name, epIdx: epIdx, svIdx: svIdx, startAt: startAt);
  }

  void _showPlayError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) { if (didPop) context.read<PlayerProvider>().closePlayer(); },
      child: Scaffold(
        backgroundColor: AppTheme.darkAnthracite,
        body: Consumer<MovieProvider>(
          builder: (context, provider, child) {
            if (provider.isLoadingDetail) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber));
            final movie = provider.movieDetail;
            if (movie == null) return const Center(child: Text("Lỗi tải thông tin", style: TextStyle(color: Colors.white)));

            // Fire once when detail first loads — _trackedClickSlugs prevents double-call
            _onMovieDetailLoaded(movie);

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      children: [
                        if (player.currentMovie?.slug == widget.movie.slug && player.chewieController != null)
                          Positioned.fill(child: Chewie(controller: player.chewieController!))
                        else
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(ApiConstants.getImageUrl(movie.thumbUrl), fit: BoxFit.contain, errorBuilder: (_, __, ___) => Container(color: Colors.grey[900])),
                              Container(color: Colors.black45),
                              Center(child: _buildPlayButton(provider)),
                            ],
                          ),
                        Positioned(top: topPadding + 10, left: 16, child: _buildCircleAction(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context))),
                        Positioned(top: topPadding + 10, right: 16, child: _buildFavoriteButton(widget.movie)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Consumer<ReviewProvider>(
                    builder: (context, reviewProvider, child) {
                      return DefaultTabController(
                        length: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(padding: const EdgeInsets.all(20.0), child: _buildMovieHeader(movie, provider.episodes, player)),
                            TabBar(
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              indicatorColor: AppTheme.primaryAmber,
                              indicatorSize: TabBarIndicatorSize.label,
                              labelColor: AppTheme.primaryAmber,
                              unselectedLabelColor: Colors.grey,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                              tabs: [const Tab(text: "Giới thiệu"), const Tab(text: "Tập phim"), Tab(text: "Đánh giá (${reviewProvider.reviews.length})"), const Tab(text: "Liên quan")],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [_buildOverviewTab(movie), _buildEpisodesTab(provider, player), _buildReviewsTab(reviewProvider), _buildRelatedTab(provider)],
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

  Widget _buildPlayButton(MovieProvider provider) {
    return GestureDetector(
      onTap: () => _playEpisode(provider.episodes, -1, -1),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [AppTheme.primaryAmber, AppTheme.secondaryOrange]),
          boxShadow: [BoxShadow(color: AppTheme.secondaryOrange.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 48),
      ),
    );
  }

  Widget _buildCircleAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildFavoriteButton(Movie movie) {
    return Consumer<MovieProvider>(
      builder: (context, movieProv, _) {
        final isFav = movieProv.isFavorite(movie.slug);
        return GestureDetector(
          onTap: () => movieProv.toggleFavorite(movie),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
            child: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? Colors.red : Colors.white, size: 20),
          ),
        );
      },
    );
  }

  Widget _buildMovieHeader(Movie movie, List<EpisodeServer> episodes, PlayerProvider player) {
    final bool isPlayingThis = player.currentMovie?.slug == widget.movie.slug;
    String currentEpName = "1";
    if (isPlayingThis) currentEpName = player.currentEpisodeName ?? "1";
    else {
      final history = context.read<MovieProvider>().getHistoryForMovie(widget.movie.slug);
      if (history != null && history.episodeName != null) currentEpName = history.episodeName!;
    }
    final primaryGenre = movie.categoryNames.values.isNotEmpty ? movie.categoryNames.values.first : "Phim";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(movie.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.secondaryAnthracite, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
              child: Text("${currentEpName.startsWith('Tập') ? currentEpName : "Tập $currentEpName"}/${movie.episodeTotal ?? '??'}", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: AppTheme.primaryAmber, size: 18),
            const SizedBox(width: 4),
            Consumer<ReviewProvider>(builder: (context, revProv, _) {
              final double score10 = revProv.averageRating * 2;
              return Text(revProv.reviews.isEmpty ? "0.0" : score10.toStringAsFixed(1), style: const TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 16));
            }),
            const SizedBox(width: 16),
            Text("${movie.year}  •  $primaryGenre  •  ${movie.durationLabel ?? '45 phút'}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewTab(Movie movie) {
    final String content = movie.content?.replaceAll(RegExp(r'<[^>]*>'), '') ?? "Không có mô tả.";
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content, maxLines: _isDescriptionExpanded ? null : 4, style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 15)),
          GestureDetector(onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded), child: Text(_isDescriptionExpanded ? "Thu gọn" : "Xem thêm...", style: const TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.bold))),
          const SizedBox(height: 24),
          _buildDetailInfo("Đạo diễn", movie.directors.isEmpty ? "Đang cập nhật" : movie.directors.join(', ')),
          _buildDetailInfo("Diễn viên", movie.actors.isEmpty ? "Đang cập nhật" : movie.actors.join(', ')),
          _buildDetailInfo("Thể loại", movie.categoryNames.values.join(', ')),
        ],
      ),
    );
  }

  Widget _buildDetailInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ]),
    );
  }

  Widget _buildEpisodesTab(MovieProvider provider, PlayerProvider player) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.episodes.length,
      itemBuilder: (context, sIdx) {
        final server = provider.episodes[sIdx];
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2),
          itemCount: server.serverData.length,
          itemBuilder: (context, eIdx) {
            final isPlaying = player.currentMovie?.slug == widget.movie.slug && player.currentEpisodeIndex == eIdx && player.currentServerIndex == sIdx;
            return GestureDetector(
              onTap: () => _playEpisode(provider.episodes, sIdx, eIdx),
              child: Container(
                decoration: BoxDecoration(
                  color: isPlaying ? AppTheme.primaryAmber : AppTheme.secondaryAnthracite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isPlaying ? AppTheme.primaryAmber : Colors.white.withValues(alpha: 0.05)),
                ),
                alignment: Alignment.center,
                child: Text(server.serverData[eIdx].name, style: TextStyle(color: isPlaying ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRelatedTab(MovieProvider provider) {
    if (provider.relatedMovies.isEmpty) return const Center(child: Text("Không có phim liên quan", style: TextStyle(color: Colors.grey)));
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 12, childAspectRatio: 0.65),
      itemCount: provider.relatedMovies.length,
      itemBuilder: (context, index) => MovieCard(movie: provider.relatedMovies[index]),
    );
  }

  Widget _buildReviewsTab(ReviewProvider reviewProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final bool hasReviewed = user != null && reviewProvider.reviews.any((r) => r.userId == user.uid);

    return Column(
      children: [
        if (user != null && !hasReviewed)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primaryAmber, AppTheme.secondaryOrange]), borderRadius: BorderRadius.circular(16)),
              child: ElevatedButton(
                onPressed: () => _showReviewDialog(null),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, minimumSize: const Size(double.infinity, 50)),
                child: const Text("Viết đánh giá của bạn", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        Expanded(
          child: reviewProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
              : reviewProvider.reviews.isEmpty
                  ? const Center(child: Text("Chưa có đánh giá nào", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: reviewProvider.reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviewProvider.reviews[index];
                        return _buildReviewItem(review, user != null && review.userId == user.uid);
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryAnthracite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isMyReview ? AppTheme.primaryAmber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: AppTheme.primaryAmber.withValues(alpha: 0.1), radius: 18, child: Text(firstLetter, style: const TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(review.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    if (isMyReview)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                        color: AppTheme.secondaryAnthracite,
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _showReviewDialog(review);
                          } else if (value == 'delete') {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            if (authProvider.currentUser != null) {
                              await Provider.of<ReviewProvider>(context, listen: false).deleteReview(widget.movie.slug, authProvider.currentUser!.uid);
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text("Sửa", style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 'delete', child: Text("Xóa", style: TextStyle(color: Colors.redAccent))),
                        ],
                      )
                    else
                      Text(date, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
                if (isMyReview) Text(date, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ])),
              if (!isMyReview) RatingBarIndicator(rating: review.rating, itemBuilder: (context, index) => const Icon(Icons.star_rounded, color: AppTheme.primaryAmber), itemCount: 5, itemSize: 16),
            ],
          ),
          if (isMyReview) const SizedBox(height: 8),
          if (isMyReview) RatingBarIndicator(rating: review.rating, itemBuilder: (context, index) => const Icon(Icons.star_rounded, color: AppTheme.primaryAmber), itemCount: 5, itemSize: 16),
          const SizedBox(height: 12),
          Text(review.comment, style: const TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 12),
          
          // Nút Phản hồi
          GestureDetector(
            onTap: () => _showReplyDialog(review),
            child: Row(
              children: [
                const Icon(Icons.reply_rounded, color: AppTheme.primaryAmber, size: 16),
                const SizedBox(width: 4),
                Text(
                  review.replies.isEmpty ? "Phản hồi" : "${review.replies.length} phản hồi",
                  style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Danh sách Phản hồi
          if (review.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...(_expandedReplies[review.userId] == true ? review.replies : review.replies.take(2))
                      .map((reply) => _buildReplyItem(review, reply)),
                  if (review.replies.length > 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 34),
                      child: InkWell(
                        onTap: () => setState(() => _expandedReplies[review.userId] = !(_expandedReplies[review.userId] ?? false)),
                        child: Text(
                          _expandedReplies[review.userId] == true ? "Thu gọn" : "Xem thêm ${review.replies.length - 2} phản hồi...",
                          style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
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

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, backgroundColor: AppTheme.primaryAmber.withValues(alpha: 0.1), child: Text(reply.userName[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 10))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(reply.userName, style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 12, fontWeight: FontWeight.bold)),
                    if (isMyReply)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 16),
                        padding: EdgeInsets.zero,
                        color: AppTheme.secondaryAnthracite,
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _showReplyDialog(parentReview, existingReply: reply);
                          } else if (value == 'delete') {
                            await Provider.of<ReviewProvider>(context, listen: false).deleteReply(widget.movie.slug, parentReview.userId, reply.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text("Sửa", style: TextStyle(color: Colors.white, fontSize: 13))),
                          const PopupMenuItem(value: 'delete', child: Text("Xóa", style: TextStyle(color: Colors.redAccent, fontSize: 13))),
                        ],
                      ),
                  ],
                ),
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
      backgroundColor: AppTheme.secondaryAnthracite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existingReply == null ? "Phản hồi @${review.userName}" : "Chỉnh sửa phản hồi", style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: commentController, maxLines: 3, autofocus: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Viết phản hồi của bạn...", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (authProvider.currentUser == null || commentController.text.trim().isEmpty) return;
                if (existingReply == null) {
                  await Provider.of<ReviewProvider>(context, listen: false).addReply(movieSlug: widget.movie.slug, reviewUserId: review.userId, text: commentController.text, user: authProvider.currentUser!);
                } else {
                  await Provider.of<ReviewProvider>(context, listen: false).updateReply(movieSlug: widget.movie.slug, reviewUserId: review.userId, replyId: existingReply.id, newText: commentController.text);
                }
                if (!mounted) return; Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text(existingReply == null ? "GỬI PHẢN HỒI" : "CẬP NHẬT"),
            ),
            const SizedBox(height: 32),
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
      backgroundColor: AppTheme.secondaryAnthracite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Đánh giá của bạn", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            RatingBar.builder(initialRating: rating, minRating: 1, direction: Axis.horizontal, allowHalfRating: true, itemPadding: const EdgeInsets.symmetric(horizontal: 4.0), itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: AppTheme.primaryAmber), onRatingUpdate: (val) => rating = val),
            const SizedBox(height: 24),
            TextField(controller: commentController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Cảm nhận của bạn...", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (authProvider.currentUser == null) return;
                await Provider.of<ReviewProvider>(context, listen: false).addOrUpdateReview(movieSlug: widget.movie.slug, rating: rating, comment: commentController.text, user: authProvider.currentUser!, movie: _movieProvider?.movieDetail ?? widget.movie);
                if (!mounted) return; Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("GỬI ĐÁNH GIÁ"),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
