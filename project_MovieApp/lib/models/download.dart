import '../models/movie.dart';

enum DownloadStatus {
  pending,
  downloading,
  compressing,
  completed,
  failed,
  cancelled,
}

enum DownloadQuality {
  low,      // 480p, CRF 28, ~40% original size
  medium,   // 720p, CRF 25, ~60% original size
  high,     // 720p, CRF 22, ~80% original size
}

extension DownloadQualityExtension on DownloadQuality {
  String get label {
    switch (this) {
      case DownloadQuality.low:
        return '480p - Tiết kiệm';
      case DownloadQuality.medium:
        return '720p - Cân bằng';
      case DownloadQuality.high:
        return '720p - Chất lượng';
    }
  }

  String get shortLabel {
    switch (this) {
      case DownloadQuality.low:
        return '480p';
      case DownloadQuality.medium:
        return '720p';
      case DownloadQuality.high:
        return 'HD';
    }
  }

  int get crfValue {
    switch (this) {
      case DownloadQuality.low:
        return 28;
      case DownloadQuality.medium:
        return 25;
      case DownloadQuality.high:
        return 22;
    }
  }

  String get resolution {
    switch (this) {
      case DownloadQuality.low:
        return '854x480';
      case DownloadQuality.medium:
        return '1280x720';
      case DownloadQuality.high:
        return '1280x720';
    }
  }
}

class DownloadedEpisode {
  final String episodeName;
  final String localPath;
  final int duration; // seconds
  final int fileSize; // bytes
  final DateTime downloadedAt;
  final DownloadQuality quality;

  DownloadedEpisode({
    required this.episodeName,
    required this.localPath,
    required this.duration,
    required this.fileSize,
    required this.downloadedAt,
    required this.quality,
  });

  factory DownloadedEpisode.fromJson(Map<String, dynamic> json) {
    return DownloadedEpisode(
      episodeName: json['episode_name'] ?? '',
      localPath: json['local_path'] ?? '',
      duration: json['duration'] ?? 0,
      fileSize: json['file_size'] ?? 0,
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(json['downloaded_at'] ?? 0),
      quality: DownloadQuality.values[json['quality'] ?? 1],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'episode_name': episodeName,
      'local_path': localPath,
      'duration': duration,
      'file_size': fileSize,
      'downloaded_at': downloadedAt.millisecondsSinceEpoch,
      'quality': quality.index,
    };
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class Download {
  final String id;
  final Movie movie;
  final String episodeName;
  final String episodeSlug;
  final String sourceUrl; // HLS m3u8 URL
  final Map<String, String>? headers; // HTTP headers (Referer, Origin, etc.)
  final DownloadQuality quality;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? localPath;
  final int fileSize; // bytes

  // Progress tracking
  String? stage; // 'downloading', 'compressing', 'finalizing'
  int? downloadedBytes;
  int? totalBytes;

  Download({
    required this.id,
    required this.movie,
    required this.episodeName,
    required this.episodeSlug,
    required this.sourceUrl,
    this.headers,
    required this.quality,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.localPath,
    this.fileSize = 0,
    this.stage,
    this.downloadedBytes,
    this.totalBytes,
  });

  factory Download.fromJson(Map<String, dynamic> json) {
    return Download(
      id: json['id'] ?? '',
      movie: Movie.fromJson(json['movie'] ?? {}),
      episodeName: json['episode_name'] ?? '',
      episodeSlug: json['episode_slug'] ?? '',
      sourceUrl: json['source_url'] ?? '',
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      quality: DownloadQuality.values[json['quality'] ?? 1],
      status: DownloadStatus.values[json['status'] ?? 0],
      progress: (json['progress'] ?? 0.0).toDouble(),
      errorMessage: json['error_message'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] ?? 0),
      completedAt: json['completed_at'] != null ? DateTime.fromMillisecondsSinceEpoch(json['completed_at']) : null,
      localPath: json['local_path'],
      fileSize: json['file_size'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movie': movie.toJson(),
      'episode_name': episodeName,
      'episode_slug': episodeSlug,
      'source_url': sourceUrl,
      'headers': headers,
      'quality': quality.index,
      'status': status.index,
      'progress': progress,
      'error_message': errorMessage,
      'created_at': createdAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'local_path': localPath,
      'file_size': fileSize,
    };
  }

  String get formattedSize {
    if (fileSize == 0) return '...';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get statusLabel {
    switch (status) {
      case DownloadStatus.pending:
        return 'Đang chờ';
      case DownloadStatus.downloading:
        return stage == 'compressing' ? 'Nén video...' : 'Đang tải...';
      case DownloadStatus.compressing:
        return 'Nén video...';
      case DownloadStatus.completed:
        return 'Hoàn thành';
      case DownloadStatus.failed:
        return 'Thất bại';
      case DownloadStatus.cancelled:
        return 'Đã hủy';
    }
  }

  Download copyWith({
    String? id,
    Movie? movie,
    String? episodeName,
    String? episodeSlug,
    String? sourceUrl,
    Map<String, String>? headers,
    DownloadQuality? quality,
    DownloadStatus? status,
    double? progress,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
    String? localPath,
    int? fileSize,
    String? stage,
    int? downloadedBytes,
    int? totalBytes,
  }) {
    return Download(
      id: id ?? this.id,
      movie: movie ?? this.movie,
      episodeName: episodeName ?? this.episodeName,
      episodeSlug: episodeSlug ?? this.episodeSlug,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      headers: headers ?? this.headers,
      quality: quality ?? this.quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      localPath: localPath ?? this.localPath,
      fileSize: fileSize ?? this.fileSize,
      stage: stage ?? this.stage,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

class DownloadedMovie {
  final Movie movie;
  final List<DownloadedEpisode> episodes;
  final DateTime lastUpdated;

  DownloadedMovie({
    required this.movie,
    required this.episodes,
    required this.lastUpdated,
  });

  factory DownloadedMovie.fromJson(Map<String, dynamic> json) {
    return DownloadedMovie(
      movie: Movie.fromJson(json['movie'] ?? {}),
      episodes: (json['episodes'] as List? ?? [])
          .map((e) => DownloadedEpisode.fromJson(e))
          .toList(),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(json['last_updated'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movie': movie.toJson(),
      'episodes': episodes.map((e) => e.toJson()).toList(),
      'last_updated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  int get totalSize => episodes.fold(0, (sum, ep) => sum + ep.fileSize);

  String get formattedTotalSize {
    final size = totalSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  int get episodeCount => episodes.length;

  bool hasEpisode(String episodeName) {
    return episodes.any((ep) => ep.episodeName == episodeName);
  }

  DownloadedEpisode? getEpisode(String episodeName) {
    try {
      return episodes.firstWhere((ep) => ep.episodeName == episodeName);
    } catch (_) {
      return null;
    }
  }
}
