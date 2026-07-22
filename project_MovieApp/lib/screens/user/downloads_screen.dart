import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/download.dart';
import '../../models/movie.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../constants/api_constants.dart';
import '../../themes/app_theme.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkAnthracite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('PHIM ĐÃ TẢI', style: TextStyle(letterSpacing: 2)),
        actions: [
          Consumer<DownloadProvider>(
            builder: (context, provider, _) {
              if (provider.downloadedMovies.isEmpty) return const SizedBox();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: AppTheme.secondaryAnthracite,
                onSelected: (value) {
                  if (value == 'clear_all') {
                    _showClearAllDialog(context);
                  } else if (value == 'storage') {
                    _showStorageInfo(context, provider);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'storage',
                    child: Row(
                      children: [
                        Icon(Icons.storage_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text('Dung lượng', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 12),
                        Text('Xóa tất cả', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, downloadProvider, _) {
          final active = downloadProvider.activeDownloads;
          final pending = downloadProvider.pendingDownloads;
          final hasActiveOrPending = active.isNotEmpty || pending.isNotEmpty;
          final hasCompleted = downloadProvider.downloadedMovies.isNotEmpty;

          if (!hasActiveOrPending && !hasCompleted) {
            return _buildEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Active downloads section
              if (active.isNotEmpty) ...[
                _buildSectionHeader('Đang tải', Icons.downloading_rounded, AppTheme.primaryAmber),
                const SizedBox(height: 8),
                ...active.map((d) => _ActiveDownloadCard(download: d, provider: downloadProvider)),
                const SizedBox(height: 24),
              ],
              // Pending downloads section
              if (pending.isNotEmpty) ...[
                _buildSectionHeader('Đang chờ', Icons.schedule_rounded, Colors.grey),
                const SizedBox(height: 8),
                ...pending.map((d) => _PendingDownloadCard(download: d, provider: downloadProvider)),
                const SizedBox(height: 24),
              ],
              // Completed downloads section
              if (hasCompleted) ...[
                // Storage info card
                _buildStorageInfoCard(downloadProvider),
                const SizedBox(height: 16),
                if (hasActiveOrPending)
                  _buildSectionHeader('Đã tải xong', Icons.download_done_rounded, Colors.green),
                if (!hasActiveOrPending)
                  _buildSectionHeader('PHIM ĐÃ TẢI', Icons.download_done_rounded, Colors.green),
                const SizedBox(height: 8),
                ...downloadProvider.downloadedMovies.map(
                  (m) => _buildMovieCard(context, m, downloadProvider),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'Chưa có phim đã tải',
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tải phim để xem offline',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfoCard(DownloadProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryAnthracite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryAmber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.download_done_rounded, color: AppTheme.primaryAmber, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider.downloadedMovies.length} phim',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dung lượng: ${provider.formattedTotalStorage}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMovieCard(BuildContext context, DownloadedMovie downloadedMovie, DownloadProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryAnthracite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Movie info header
          InkWell(
            onTap: () {
              if (downloadedMovie.episodes.isNotEmpty) {
                _playDownloadedEpisode(context, downloadedMovie.movie, downloadedMovie.episodes.first, downloadedMovie.episodes);
              } else {
                // No episodes downloaded, show message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chưa có tập nào được tải.'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.network(
                          ApiConstants.getImageUrl(downloadedMovie.movie.posterUrl.isNotEmpty 
                              ? downloadedMovie.movie.posterUrl 
                              : downloadedMovie.movie.thumbUrl),
                          width: 80,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 110,
                            color: AppTheme.darkAnthracite,
                            child: const Icon(Icons.movie, color: Colors.grey),
                          ),
                        ),
                        // Quality badge
                        if (downloadedMovie.episodes.isNotEmpty)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                downloadedMovie.episodes.first.quality.shortLabel,
                                style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Movie details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          downloadedMovie.movie.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (downloadedMovie.movie.originName != null && downloadedMovie.movie.originName!.isNotEmpty)
                          Text(
                            downloadedMovie.movie.originName!,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.video_library_rounded, color: Colors.grey, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${downloadedMovie.episodeCount} tập',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.storage_rounded, color: Colors.grey, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              downloadedMovie.formattedTotalSize,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Delete button
                  IconButton(
                    onPressed: () => _showDeleteMovieDialog(context, downloadedMovie.movie),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ),
          // Episodes list
          if (downloadedMovie.episodes.length > 1) ...[
            const Divider(color: Colors.white10, height: 1),
            _buildEpisodesList(context, downloadedMovie, provider),
          ] else ...[
            // Single episode - play directly
            const Divider(color: Colors.white10, height: 1),
            InkWell(
              onTap: () => _playDownloadedEpisode(context, downloadedMovie.movie, downloadedMovie.episodes.first, downloadedMovie.episodes),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAmber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            downloadedMovie.episodes.first.episodeName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            downloadedMovie.episodes.first.formattedSize,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_filled_rounded, color: AppTheme.primaryAmber, size: 32),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEpisodesList(BuildContext context, DownloadedMovie downloadedMovie, DownloadProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with play all button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Danh sách tập', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () {
                  // TODO: Play first episode
                  if (downloadedMovie.episodes.isNotEmpty) {
                    _playDownloadedEpisode(context, downloadedMovie.movie, downloadedMovie.episodes.first, downloadedMovie.episodes);
                  }
                },
                icon: const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.primaryAmber),
                label: const Text('Phát tập đầu', style: TextStyle(color: AppTheme.primaryAmber, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Episode chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: downloadedMovie.episodes.map((episode) {
              return InkWell(
                onTap: () => _playDownloadedEpisode(context, downloadedMovie.movie, episode, downloadedMovie.episodes),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkAnthracite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(episode.episodeName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(episode.quality.shortLabel, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _showDeleteEpisodeDialog(context, downloadedMovie.movie, episode),
                        child: const Icon(Icons.close, size: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _playDownloadedEpisode(BuildContext context, Movie movie, DownloadedEpisode episode, List<DownloadedEpisode> allEpisodes) {
    // Check if file exists
    final file = File(episode.localPath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File không tồn tại. Vui lòng tải lại.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Find the episode index in the downloaded episodes list
    final episodeIndex = allEpisodes.indexWhere((e) => e.episodeName == episode.episodeName);

    // Play the local video directly
    final playerProvider = context.read<PlayerProvider>();
    playerProvider.setLocalVideo(
      movie,
      episode.localPath,
      episode.episodeName,
      epIdx: episodeIndex >= 0 ? episodeIndex : 0,
      downloadedEpisodes: allEpisodes,
    );
  }

  void _showDeleteEpisodeDialog(BuildContext context, Movie movie, DownloadedEpisode episode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondaryAnthracite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa tập đã tải?', style: TextStyle(color: Colors.white)),
        content: Text('${episode.episodeName} sẽ bị xóa khỏi thiết bị.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<DownloadProvider>().deleteDownloadedEpisode(movie.slug, episode.episodeName);
              Navigator.pop(context);
            },
            child: const Text('XÓA', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showDeleteMovieDialog(BuildContext context, Movie movie) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondaryAnthracite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa phim đã tải?', style: TextStyle(color: Colors.white)),
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

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondaryAnthracite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa tất cả tải về?', style: TextStyle(color: Colors.white)),
        content: const Text('Tất cả phim đã tải sẽ bị xóa khỏi thiết bị. Hành động này không thể hoàn tác.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<DownloadProvider>().clearAllDownloads();
              Navigator.pop(context);
            },
            child: const Text('XÓA TẤT CẢ', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showStorageInfo(BuildContext context, DownloadProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.secondaryAnthracite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage_rounded, color: AppTheme.primaryAmber, size: 48),
            const SizedBox(height: 16),
            const Text('Dung lượng lưu trữ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStorageStat('Phim đã tải', '${provider.downloadedMovies.length}', Icons.movie_rounded),
                _buildStorageStat('Tổng dung lượng', provider.formattedTotalStorage, Icons.sd_storage_rounded),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Các file được lưu trong bộ nhớ ứng dụng và có thể bị xóa khi gỡ ứng dụng.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryAmber, size: 32),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: title.contains('PHIM') ? 2 : 0,
          ),
        ),
      ],
    );
  }
}

class _ActiveDownloadCard extends StatelessWidget {
  final Download download;
  final DownloadProvider provider;

  const _ActiveDownloadCard({required this.download, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.secondaryAnthracite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.movie.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      download.episodeName,
                      style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showCancelDialog(context),
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: download.progress > 0 ? download.progress : null,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: AppTheme.primaryAmber,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                download.stage ?? 'Đang tải...',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              Text(
                '${(download.progress * 100).toInt()}%',
                style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.secondaryAnthracite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy tải?', style: TextStyle(color: Colors.white)),
        content: Text('Hủy tải "${download.episodeName}"?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              provider.cancelDownload(download.id);
              Navigator.pop(ctx);
            },
            child: const Text('HỦY TẢI', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _PendingDownloadCard extends StatelessWidget {
  final Download download;
  final DownloadProvider provider;

  const _PendingDownloadCard({required this.download, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.secondaryAnthracite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.schedule_rounded, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  download.movie.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${download.episodeName} • ${download.quality.label}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showCancelDialog(context),
            icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.secondaryAnthracite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy tải?', style: TextStyle(color: Colors.white)),
        content: Text('Hủy tải "${download.episodeName}" khỏi hàng đợi?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              provider.cancelDownload(download.id);
              Navigator.pop(ctx);
            },
            child: const Text('XÓA', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
