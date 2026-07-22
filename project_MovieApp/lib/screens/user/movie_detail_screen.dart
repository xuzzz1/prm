import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../../models/movie.dart';
import '../../models/download.dart';
import '../../providers/movie_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/review_provider.dart';
import '../../providers/download_provider.dart';
import '../../models/review.dart';
import '../../constants/api_constants.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/movie_card.dart';
import '../../themes/app_theme.dart';
import 'downloads_screen.dart';

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
    
    // Check if episode is downloaded
    final downloadProvider = context.read<DownloadProvider>();
    final downloadedEpisode = downloadProvider.getDownloadedEpisode(movieForPlayer.slug, episode.name);
    
    if (downloadedEpisode != null) {
      // Get all downloaded episodes for this movie
      final downloadedMovie = downloadProvider.downloadedMovies.where((dm) => dm.movie.slug == movieForPlayer.slug).firstOrNull;
      
      // Play from local file
      context.read<PlayerProvider>().setLocalVideo(
        movieForPlayer,
        downloadedEpisode.localPath,
        episode.name,
        epIdx: epIdx,
        svIdx: svIdx,
        startAt: startAt,
        downloadedEpisodes: downloadedMovie?.episodes,
      );
    } else {
      // Play from network
      context.read<PlayerProvider>().setVideo(
        movieForPlayer,
        episode.linkM3u8,
        episode.name,
        epIdx: epIdx,
        svIdx: svIdx,
        startAt: startAt,
      );
    }
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
      child: Scaffold(
        backgroundColor: AppTheme.darkAnthracite,
        body: Consumer<MovieProvider>(
          builder: (context, provider, child) {
            if (provider.isLoadingDetail) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber));
            final movie = provider.movieDetail;
            if (movie == null) return _OfflineDetailView(movie: widget.movie);

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
    final isSeries = movie.type == 'series' || (movie.episodeTotal != null && movie.episodeTotal != '1' && movie.episodeTotal != 'Full');

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
        const SizedBox(height: 16),
        // Download section
        _buildDownloadSection(movie, episodes, isSeries),
      ],
    );
  }

  Widget _buildDownloadSection(Movie movie, List<EpisodeServer> episodes, bool isSeries) {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, _) {
        final downloadedCount = downloadProvider.getDownloadedEpisodeCount(movie.slug);
        final totalEpisodes = episodes.isNotEmpty ? episodes.first.serverData.length : (int.tryParse(movie.episodeTotal ?? '1') ?? 1);
        final allDownloaded = downloadedCount >= totalEpisodes && totalEpisodes > 0;
        final movieActiveDownloads = downloadProvider.activeDownloads.where((d) => d.movie.slug == movie.slug).toList();
        final moviePendingDownloads = downloadProvider.pendingDownloads.where((d) => d.movie.slug == movie.slug).toList();
        final hasActiveDownloads = movieActiveDownloads.isNotEmpty;

        // Compute aggregate progress across active downloads for this movie
        double aggregateProgress = 0.0;
        int activeCount = movieActiveDownloads.length;
        if (activeCount > 0) {
          for (var d in movieActiveDownloads) aggregateProgress += d.progress;
          aggregateProgress = aggregateProgress / activeCount;
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.secondaryAnthracite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    allDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                    color: allDownloaded ? Colors.green : AppTheme.primaryAmber,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allDownloaded ? 'Đã tải toàn bộ' :
                          downloadedCount > 0 ? 'Đã tải $downloadedCount/$totalEpisodes tập' :
                          'Tải phim để xem offline',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        if (hasActiveDownloads)
                          Text(
                            'Đang tải $activeCount tập...',
                            style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 11),
                          ),
                        if (moviePendingDownloads.isNotEmpty && !hasActiveDownloads)
                          Text(
                            'Đang chờ ${moviePendingDownloads.length} tập...',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  if (!allDownloaded)
                    GestureDetector(
                      onTap: () => _showDownloadAllDialog(context, movie, episodes, isSeries),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAmber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Tải', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  if (allDownloaded)
                    GestureDetector(
                      onTap: () => _showDeleteAllDialog(context, movie),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                ],
              ),
              // Aggregate progress bar for active downloads
              if (hasActiveDownloads) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: aggregateProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    color: AppTheme.primaryAmber,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(aggregateProgress * 100).toInt()}%',
                  style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showDownloadAllDialog(BuildContext context, Movie movie, List<EpisodeServer> episodes, bool isSeries) {
    final downloadProvider = context.read<DownloadProvider>();
    final server = episodes.isNotEmpty ? episodes.first : null;
    final episodeList = server?.serverData ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.secondaryAnthracite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Chọn tập để tải', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                episodeList.isEmpty ? 'Không có tập nào' : '${episodeList.length} tập',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (episodeList.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Không có link video', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: episodeList.length,
                    itemBuilder: (context, index) {
                      final ep = episodeList[index];
                      final isDownloaded = downloadProvider.isEpisodeDownloaded(movie.slug, ep.name);
                      final isDownloading = downloadProvider.isDownloading(movie.slug, ep.name);
                      final isPending = downloadProvider.getDownload(movie.slug, ep.name)?.status == DownloadStatus.pending;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(
                            ep.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          trailing: isDownloaded
                              ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
                              : isDownloading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAmber),
                                    )
                                  : isPending
                                      ? const Icon(Icons.schedule, color: Colors.grey, size: 22)
                                      : GestureDetector(
                                          onTap: () {
                                            Navigator.pop(context); // close episode list
                                            _showSingleEpisodeQualityDialog(context, movie, ep, episodes);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryAmber,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Tải', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
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
    );
  }

  void _showSingleEpisodeQualityDialog(BuildContext context, Movie movie, EpisodeDoc episode, List<EpisodeServer> episodes) {
    DownloadQuality selectedQuality = DownloadQuality.medium;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.secondaryAnthracite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chọn chất lượng', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(episode.name, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 20),
              ...DownloadQuality.values.map((quality) => _buildQualityOption(
                quality,
                selectedQuality == quality,
                () => setState(() => selectedQuality = quality),
              )),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startDownloadSingle(movie, episode, selectedQuality);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAmber,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('BẮT ĐẦU TẢI', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDownloadSingle(Movie movie, EpisodeDoc episode, DownloadQuality quality) async {
    final downloadProvider = context.read<DownloadProvider>();

    if (downloadProvider.isEpisodeDownloaded(movie.slug, episode.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tập này đã được tải'),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (downloadProvider.isDownloading(movie.slug, episode.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tập này đang được tải'),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang lấy link mới...'),
        backgroundColor: AppTheme.primaryAmber,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 10),
      ),
    );

    // Force re-fetch movie detail to get fresh m3u8 URL (tokens expire quickly)
    await _movieProvider!.forceReloadMovie(movie.slug);

    // Find the fresh episode data
    EpisodeDoc? freshEpisode;
    for (var server in _movieProvider!.episodes) {
      for (var ep in server.serverData) {
        if (ep.slug == episode.slug) {
          freshEpisode = ep;
          break;
        }
      }
      if (freshEpisode != null) break;
    }

    if (freshEpisode == null || freshEpisode.linkM3u8.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không lấy được link video, vui lòng thử lại'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Dismiss loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    downloadProvider.startDownload(
      movie: movie,
      episodeName: freshEpisode.name,
      episodeSlug: freshEpisode.slug,
      sourceUrl: freshEpisode.linkM3u8,
      headers: {
        'Referer': Uri.parse(freshEpisode.linkM3u8).origin,
        'Origin': Uri.parse(freshEpisode.linkM3u8).origin,
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
      quality: quality,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã bắt đầu tải: ${freshEpisode.name}'),
        backgroundColor: AppTheme.primaryAmber,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildQualityOption(DownloadQuality quality, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAmber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAmber : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primaryAmber : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quality.label, style: TextStyle(color: isSelected ? AppTheme.primaryAmber : Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(_getQualityDescription(quality), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getQualityDescription(DownloadQuality quality) {
    switch (quality) {
      case DownloadQuality.low:
        return '480p - Dung lượng thấp nhất';
      case DownloadQuality.medium:
        return '720p - Cân bằng chất lượng';
      case DownloadQuality.high:
        return '720p - Chất lượng cao nhất';
    }
  }

  void _showDeleteAllDialog(BuildContext context, Movie movie) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondaryAnthracite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa tất cả tải về?', style: TextStyle(color: Colors.white)),
        content: const Text('Tất cả các tập đã tải sẽ bị xóa khỏi thiết bị.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<DownloadProvider>().deleteDownloadedMovie(movie.slug);
              Navigator.pop(context);
            },
            child: const Text('XÓA', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (server.serverName.isNotEmpty && server.serverName != 'Default')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(server.serverName, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2),
              itemCount: server.serverData.length,
              itemBuilder: (context, eIdx) {
                final episode = server.serverData[eIdx];
                final isPlaying = player.currentMovie?.slug == widget.movie.slug && player.currentEpisodeIndex == eIdx && player.currentServerIndex == sIdx;
                final downloadProvider = context.watch<DownloadProvider>();
                final isDownloaded = downloadProvider.isEpisodeDownloaded(widget.movie.slug, episode.name);
                final activeDownload = downloadProvider.getDownload(widget.movie.slug, episode.name);

                return _EpisodeChip(
                  episode: episode,
                  isPlaying: isPlaying,
                  isDownloaded: isDownloaded,
                  activeDownload: activeDownload,
                  onTap: () => _playEpisode(provider.episodes, sIdx, eIdx),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
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
    return Column(
      children: [
        Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.currentUser;
            final hasReviewed = user != null && reviewProvider.reviews.any((r) => r.userId == user.uid);
            if (user != null && !hasReviewed) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primaryAmber, AppTheme.secondaryOrange]), borderRadius: BorderRadius.circular(16)),
                  child: ElevatedButton(
                    onPressed: () => _showReviewDialog(null),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, minimumSize: const Size(double.infinity, 50)),
                    child: const Text("Viết đánh giá của bạn", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Expanded(
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final user = authProvider.currentUser;
              return reviewProvider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
                  : reviewProvider.reviews.isEmpty
                      ? const Center(child: Text("Chưa có đánh giá nào", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          itemCount: reviewProvider.reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviewProvider.reviews[index];
                            return _buildReviewItem(review, user != null && review.userId == user.uid);
                          },
                        );
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
                print("[DEBUG] Submit button tapped. comment='${commentController.text}', rating=$rating");
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                print("[DEBUG] currentUser = ${authProvider.currentUser?.uid}");
                if (authProvider.currentUser == null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng đăng nhập để gửi đánh giá.")));
                  return;
                }
                print("[DEBUG] Calling addOrUpdateReview...");
                try {
                  await Provider.of<ReviewProvider>(context, listen: false).addOrUpdateReview(movieSlug: widget.movie.slug, rating: rating, comment: commentController.text, user: authProvider.currentUser!, movie: _movieProvider?.movieDetail ?? widget.movie);
                  print("[DEBUG] addOrUpdateReview succeeded");
                } catch (e, st) {
                  print("[DEBUG] addOrUpdateReview FAILED: $e\n$st");
                }
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

class _OfflineDetailView extends StatelessWidget {
  final Movie movie;

  const _OfflineDetailView({required this.movie});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 72, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'Bạn đang offline',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Xem phim đã tải'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeChip extends StatelessWidget {
  final EpisodeDoc episode;
  final bool isPlaying;
  final bool isDownloaded;
  final Download? activeDownload;
  final VoidCallback onTap;

  const _EpisodeChip({
    required this.episode,
    required this.isPlaying,
    required this.isDownloaded,
    required this.activeDownload,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDownloading = activeDownload != null && activeDownload!.status == DownloadStatus.downloading;
    final bool isPending = activeDownload != null && activeDownload!.status == DownloadStatus.pending;
    final double progress = activeDownload?.progress ?? 0.0;

    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isPlaying ? AppTheme.primaryAmber : AppTheme.secondaryAnthracite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isPlaying ? AppTheme.primaryAmber : Colors.white.withValues(alpha: 0.05)),
            ),
            alignment: Alignment.center,
            child: Text(episode.name, style: TextStyle(color: isPlaying ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        // Download indicator overlay
        if (isDownloaded)
          Positioned(
            top: 4,
            right: 4,
            child: Icon(
              Icons.download_done_rounded,
              size: 14,
              color: Colors.green,
            ),
          ),
        if (isDownloading)
          Positioned(
            bottom: 4,
            right: 4,
            child: SizedBox(
              width: 14,
              height: 14,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 1.5,
                    value: progress > 0 ? progress : null,
                    color: AppTheme.primaryAmber,
                    backgroundColor: Colors.white24,
                  ),
                  if (progress > 0)
                    Text(
                      '${(progress * 100).toInt()}',
                      style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
        if (isPending)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
              child: const Text('Chờ', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}
