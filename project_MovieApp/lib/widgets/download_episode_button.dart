import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download.dart';
import '../models/movie.dart';
import '../providers/download_provider.dart';
import '../themes/app_theme.dart';

class DownloadEpisodeButton extends StatelessWidget {
  final Movie movie;
  final EpisodeDoc episode;
  final VoidCallback? onDownloadComplete;

  const DownloadEpisodeButton({
    super.key,
    required this.movie,
    required this.episode,
    this.onDownloadComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, _) {
        final download = downloadProvider.getDownload(movie.slug, episode.name);
        final isDownloaded = downloadProvider.isEpisodeDownloaded(movie.slug, episode.name);

        if (isDownloaded) {
          return _buildDownloadedState(context, downloadProvider);
        }

        if (download != null && download.status == DownloadStatus.downloading) {
          return _buildDownloadingState(context, downloadProvider, download);
        }

        if (download != null && download.status == DownloadStatus.pending) {
          return _buildPendingState(context, downloadProvider, download);
        }

        if (download != null && download.status == DownloadStatus.failed) {
          return _buildFailedState(context, downloadProvider, download);
        }

        return _buildDownloadButton(context, downloadProvider);
      },
    );
  }

  Widget _buildDownloadButton(BuildContext context, DownloadProvider provider) {
    return GestureDetector(
      onTap: () => _showQualityDialog(context, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryAmber.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_rounded, color: AppTheme.primaryAmber, size: 16),
            SizedBox(width: 4),
            Text('Tải', style: TextStyle(color: AppTheme.primaryAmber, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingState(BuildContext context, DownloadProvider provider, Download download) {
    return GestureDetector(
      onTap: () => _showDownloadProgress(context, download),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryAmber.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: download.progress > 0 ? download.progress : null,
                color: AppTheme.primaryAmber,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(download.progress * 100).toInt()}%',
              style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingState(BuildContext context, DownloadProvider provider, Download download) {
    return GestureDetector(
      onTap: () => _showPendingOptions(context, provider, download),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, color: Colors.grey, size: 14),
            SizedBox(width: 4),
            Text('Chờ', style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedState(BuildContext context, DownloadProvider provider, Download download) {
    return GestureDetector(
      onTap: () => _showFailedOptions(context, provider, download),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
            SizedBox(width: 4),
            Text('Thử lại', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadedState(BuildContext context, DownloadProvider provider) {
    return GestureDetector(
      onTap: () => _showDownloadedOptions(context, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text('Đã tải', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showQualityDialog(BuildContext context, DownloadProvider provider) {
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
              const Text('Chọn chất lượng tải về', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                    provider.startDownload(
                      movie: movie,
                      episodeName: episode.name,
                      episodeSlug: episode.slug,
                      sourceUrl: episode.linkM3u8,
                      headers: {
                        'Referer': Uri.parse(episode.linkM3u8).origin,
                        'Origin': Uri.parse(episode.linkM3u8).origin,
                        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                      },
                      quality: selectedQuality,
                    );
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

  Widget _buildQualityOption(DownloadQuality quality, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAmber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAmber : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primaryAmber : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quality.label, style: TextStyle(color: isSelected ? AppTheme.primaryAmber : Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_getQualityDescription(quality), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primaryAmber, borderRadius: BorderRadius.circular(4)),
                child: const Text('Chọn', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  String _getQualityDescription(DownloadQuality quality) {
    switch (quality) {
      case DownloadQuality.low:
        return 'Dung lượng thấp, tiết kiệm bộ nhớ';
      case DownloadQuality.medium:
        return 'Cân bằng giữa chất lượng và dung lượng';
      case DownloadQuality.high:
        return 'Chất lượng cao nhất, dung lượng lớn hơn';
    }
  }

  void _showDownloadProgress(BuildContext context, Download download) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.secondaryAnthracite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(download.episodeName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: download.progress > 0 ? download.progress : null,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: AppTheme.primaryAmber,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(download.stage ?? 'Đang tải...', style: const TextStyle(color: Colors.grey)),
                Text('${(download.progress * 100).toInt()}%', style: const TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                context.read<DownloadProvider>().cancelDownload(download.id);
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('HỦY TẢI', style: TextStyle(color: Colors.redAccent)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPendingOptions(BuildContext context, DownloadProvider provider, Download download) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.secondaryAnthracite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            const Text('Đang chờ trong hàng đợi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${download.quality.label}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      provider.cancelDownload(download.id);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('HỦY', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFailedOptions(BuildContext context, DownloadProvider provider, Download download) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.secondaryAnthracite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text('Tải thất bại', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(download.errorMessage ?? 'Lỗi không xác định', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      provider.cancelDownload(download.id);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('XÓA', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      provider.retryDownload(download.id);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAmber,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('THỬ LẠI', style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDownloadedOptions(BuildContext context, DownloadProvider provider) {
    final downloadedEpisode = provider.getDownloadedEpisode(movie.slug, episode.name);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.secondaryAnthracite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text('Đã tải xuống', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (downloadedEpisode != null) ...[
              Text(downloadedEpisode.quality.label, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(downloadedEpisode.formattedSize, style: const TextStyle(color: AppTheme.primaryAmber)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      provider.deleteDownloadedEpisode(movie.slug, episode.name);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('XÓA', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDownloadComplete?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAmber,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('PHÁT', style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
