import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download.dart';
import '../models/movie.dart';
import '../services/download_service.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();

  // All downloads (active and completed)
  final Map<String, Download> _downloads = {};

  // Download queue
  final List<String> _downloadQueue = [];

  // Downloaded movies (completed)
  final Map<String, DownloadedMovie> _downloadedMovies = {};

  // Active download sessions
  final Map<String, bool> _activeDownloads = {};

  // Max concurrent downloads
  static const int _maxConcurrent = 1;

  // Getters
  List<Download> get activeDownloads =>
      _downloads.values.where((d) => d.status == DownloadStatus.downloading).toList();

  List<Download> get pendingDownloads =>
      _downloads.values.where((d) => d.status == DownloadStatus.pending).toList();

  List<Download> get completedDownloads =>
      _downloads.values.where((d) => d.status == DownloadStatus.completed).toList();

  List<Download> get failedDownloads =>
      _downloads.values.where((d) => d.status == DownloadStatus.failed).toList();

  List<Download> get allDownloads => _downloads.values.toList();

  List<DownloadedMovie> get downloadedMovies => _downloadedMovies.values.toList();

  int get activeDownloadCount => activeDownloads.length;

  bool get hasActiveDownloads => activeDownloads.isNotEmpty;

  DownloadProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final downloadsJson = prefs.getStringList('downloads') ?? [];
    final moviesJson = prefs.getStringList('downloaded_movies') ?? [];

    // Load downloads
    for (var json in downloadsJson) {
      try {
        final download = Download.fromJson(jsonDecode(json));
        _downloads[download.id] = download;
      } catch (e) {
        print('Error loading download: $e');
      }
    }

    // Load downloaded movies
    for (var json in moviesJson) {
      try {
        final movie = DownloadedMovie.fromJson(jsonDecode(json));
        _downloadedMovies[movie.movie.slug] = movie;
      } catch (e) {
        print('Error loading downloaded movie: $e');
      }
    }

    // Resume any pending downloads
    _resumePendingDownloads();
    notifyListeners();
  }

  Future<void> _saveDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final downloadsJson = _downloads.values.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList('downloads', downloadsJson);
  }

  Future<void> _saveDownloadedMovies() async {
    final prefs = await SharedPreferences.getInstance();
    final moviesJson = _downloadedMovies.values.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('downloaded_movies', moviesJson);
  }

  // Check if an episode is already downloaded
  bool isEpisodeDownloaded(String movieSlug, String episodeName) {
    final movie = _downloadedMovies[movieSlug];
    if (movie == null) return false;
    return movie.hasEpisode(episodeName);
  }

  // Check if a download is in progress
  bool isDownloading(String movieSlug, String episodeName) {
    return _downloads.values.any((d) =>
        d.movie.slug == movieSlug &&
        d.episodeName == episodeName &&
        (d.status == DownloadStatus.downloading || d.status == DownloadStatus.pending));
  }

  // Get download progress for an episode
  Download? getDownload(String movieSlug, String episodeName) {
    try {
      return _downloads.values.firstWhere(
        (d) => d.movie.slug == movieSlug && d.episodeName == episodeName,
      );
    } catch (_) {
      return null;
    }
  }

  // Get downloaded episode
  DownloadedEpisode? getDownloadedEpisode(String movieSlug, String episodeName) {
    final movie = _downloadedMovies[movieSlug];
    if (movie == null) return null;
    return movie.getEpisode(episodeName);
  }

  // Start a download
  Future<void> startDownload({
    required Movie movie,
    required String episodeName,
    required String episodeSlug,
    required String sourceUrl,
    Map<String, String>? headers,
    required DownloadQuality quality,
  }) async {
    // Check if already downloaded or downloading
    if (isEpisodeDownloaded(movie.slug, episodeName)) {
      return;
    }

    if (isDownloading(movie.slug, episodeName)) {
      return;
    }

    // Create download entry
    final id = '${movie.slug}_$episodeName'.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w_]'), '');
    final download = Download(
      id: id,
      movie: movie,
      episodeName: episodeName,
      episodeSlug: episodeSlug,
      sourceUrl: sourceUrl,
      headers: headers,
      quality: quality,
      status: DownloadStatus.pending,
      createdAt: DateTime.now(),
    );

    _downloads[id] = download;
    _downloadQueue.add(id);
    notifyListeners();
    await _saveDownloads();

    // Start download if under limit
    _processQueue();
  }

  void _processQueue() {
    while (activeDownloadCount < _maxConcurrent && _downloadQueue.isNotEmpty) {
      final id = _downloadQueue.removeAt(0);
      final download = _downloads[id];
      if (download != null && download.status == DownloadStatus.pending) {
        _executeDownload(download);
      }
    }
  }

  void _resumePendingDownloads() {
    for (var download in pendingDownloads) {
      if (!_downloadQueue.contains(download.id)) {
        _downloadQueue.add(download.id);
      }
    }
    _processQueue();
  }

  Future<void> _executeDownload(Download download) async {
    final id = download.id;
    _activeDownloads[id] = true;

    // Update status to downloading
    _downloads[id] = download.copyWith(status: DownloadStatus.downloading);
    notifyListeners();

    try {
      final outputName = '${download.movie.slug}_${download.episodeName}'.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w_]'), '');

      print('[DownloadProvider] Starting download: ${download.episodeName} | quality: ${download.quality}');

      final localPath = await _downloadService.downloadWithProgress(
        url: download.sourceUrl,
        headers: download.headers,
        outputName: outputName,
        quality: download.quality,
        onProgress: (progress, stage, downloadedBytes, totalBytes) {
          if (_activeDownloads[id] != true) return;
          final pct = progress != null ? (progress * 100).toInt() : null;
          print('[DownloadProvider] Progress ${download.episodeName}: ${pct != null ? '$pct%' : 'indeterminate'} | stage: $stage');
          _downloads[id] = _downloads[id]!.copyWith(
            progress: progress,
            stage: stage,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
          );
          notifyListeners();
        },
      );
      print('[DownloadProvider] downloadWithProgress returned: $localPath');

      if (_activeDownloads[id] != true) {
        // Download was cancelled
        return;
      }

      if (localPath != null) {
        // Download successful
        final fileSize = await _downloadService.getDownloadSize(localPath);

        // Add to downloaded movies
        final downloadedMovie = _downloadedMovies[download.movie.slug];
        if (downloadedMovie != null) {
          // Update existing movie
          final newEpisodes = List<DownloadedEpisode>.from(downloadedMovie.episodes);
          newEpisodes.add(DownloadedEpisode(
            episodeName: download.episodeName,
            localPath: localPath,
            duration: 0,
            fileSize: fileSize,
            downloadedAt: DateTime.now(),
            quality: download.quality,
          ));
          _downloadedMovies[download.movie.slug] = DownloadedMovie(
            movie: downloadedMovie.movie,
            episodes: newEpisodes,
            lastUpdated: DateTime.now(),
          );
        } else {
          // Create new movie entry
          _downloadedMovies[download.movie.slug] = DownloadedMovie(
            movie: download.movie,
            episodes: [
              DownloadedEpisode(
                episodeName: download.episodeName,
                localPath: localPath,
                duration: 0,
                fileSize: fileSize,
                downloadedAt: DateTime.now(),
                quality: download.quality,
              ),
            ],
            lastUpdated: DateTime.now(),
          );
        }

        // Update download status
        _downloads[id] = _downloads[id]!.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          localPath: localPath,
          fileSize: fileSize,
          completedAt: DateTime.now(),
        );

        await _saveDownloads();
        await _saveDownloadedMovies();
      } else {
        throw Exception('Download returned null');
      }
    } catch (e) {
      _downloads[id] = _downloads[id]!.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
      await _saveDownloads();
    } finally {
      _activeDownloads.remove(id);
      notifyListeners();
      _processQueue();
    }
  }

  // Cancel a download
  Future<void> cancelDownload(String id) async {
    _activeDownloads[id] = false;
    _downloadQueue.remove(id);

    _downloads[id] = _downloads[id]!.copyWith(status: DownloadStatus.cancelled);
    notifyListeners();
    await _saveDownloads();
  }

  // Retry a failed download
  Future<void> retryDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.failed) return;

    _downloads[id] = download.copyWith(
      status: DownloadStatus.pending,
      progress: 0.0,
      errorMessage: null,
    );
    _downloadQueue.add(id);
    notifyListeners();
    await _saveDownloads();
    _processQueue();
  }

  // Delete a downloaded episode
  Future<void> deleteDownloadedEpisode(String movieSlug, String episodeName) async {
    final downloadedMovie = _downloadedMovies[movieSlug];
    if (downloadedMovie == null) return;

    final episode = downloadedMovie.getEpisode(episodeName);
    if (episode == null) return;

    // Delete file
    await _downloadService.deleteDownload(episode.localPath);

    // Update movie
    final newEpisodes = downloadedMovie.episodes.where((e) => e.episodeName != episodeName).toList();
    if (newEpisodes.isEmpty) {
      _downloadedMovies.remove(movieSlug);
    } else {
      _downloadedMovies[movieSlug] = DownloadedMovie(
        movie: downloadedMovie.movie,
        episodes: newEpisodes,
        lastUpdated: DateTime.now(),
      );
    }

    // Remove from downloads list
    _downloads.removeWhere((id, d) => d.movie.slug == movieSlug && d.episodeName == episodeName);

    await _saveDownloadedMovies();
    await _saveDownloads();
    notifyListeners();
  }

  // Delete all downloaded episodes for a movie
  Future<void> deleteDownloadedMovie(String movieSlug) async {
    final downloadedMovie = _downloadedMovies[movieSlug];
    if (downloadedMovie == null) return;

    // Delete all files
    for (var episode in downloadedMovie.episodes) {
      await _downloadService.deleteDownload(episode.localPath);
    }

    _downloadedMovies.remove(movieSlug);

    // Remove from downloads list
    _downloads.removeWhere((id, d) => d.movie.slug == movieSlug);

    await _saveDownloadedMovies();
    await _saveDownloads();
    notifyListeners();
  }

  // Clear all downloads
  Future<void> clearAllDownloads() async {
    // Cancel active downloads
    for (var id in _activeDownloads.keys.toList()) {
      _activeDownloads[id] = false;
    }
    _activeDownloads.clear();
    _downloadQueue.clear();

    // Delete all downloaded files
    await _downloadService.clearAllDownloads();

    _downloads.clear();
    _downloadedMovies.clear();

    await _saveDownloads();
    await _saveDownloadedMovies();
    notifyListeners();
  }

  // Get local file path for playback
  String? getLocalPath(String movieSlug, String episodeName) {
    final episode = getDownloadedEpisode(movieSlug, episodeName);
    return episode?.localPath;
  }

  // Check if movie has any downloaded episodes
  bool hasAnyDownloadedEpisode(String movieSlug) {
    return _downloadedMovies.containsKey(movieSlug);
  }

  // Get download count for a movie
  int getDownloadedEpisodeCount(String movieSlug) {
    return _downloadedMovies[movieSlug]?.episodeCount ?? 0;
  }

  // Total storage used
  int get totalStorageUsed {
    return _downloadedMovies.values.fold(0, (sum, movie) => sum + movie.totalSize);
  }

  String get formattedTotalStorage {
    final size = totalStorageUsed;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
