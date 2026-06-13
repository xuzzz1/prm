import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/movie.dart';
import '../services/recommendation_service.dart';
import 'movie_provider.dart';

class PlayerProvider extends ChangeNotifier {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Widget? _videoWidget; // Cache widget để tránh giật video khi rebuild

  Movie? _currentMovie;
  String? _currentEpisodeName;
  int currentEpisodeIndex = 0;
  int currentServerIndex = 0;

  bool _isMiniPlayerActive = false;
  bool _isExpanded = false;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _progressTimer;
  MovieProvider? _movieProvider;
  final RecommendationService _recommendationService = RecommendationService();

  // Milestone for affinity tracking (90% completion)
  final Set<String> _watchedMilestone90 = {};

  // Getters
  VideoPlayerController? get videoController => _videoController;
  ChewieController? get chewieController => _chewieController;
  Widget? get videoWidget => _videoWidget;
  Movie? get currentMovie => _currentMovie;
  String? get currentEpisodeName => _currentEpisodeName;
  bool get isMiniPlayerActive => _isMiniPlayerActive;
  bool get isExpanded => _isExpanded;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setMovieProvider(MovieProvider provider) {
    _movieProvider = provider;
  }

  Future<void> setVideo(Movie movie, String url, String episodeName, {int epIdx = 0, int svIdx = 0, Duration? startAt}) async {
    if (_currentMovie?.slug == movie.slug && _currentEpisodeName == episodeName) {
      _isExpanded = true;
      notifyListeners();
      return;
    }

    _stopProgressTimer();

    _isLoading = true;
    _errorMessage = null;
    _isMiniPlayerActive = true;
    _isExpanded = true; 
    _currentMovie = movie;
    _currentEpisodeName = episodeName;
    currentEpisodeIndex = epIdx;
    currentServerIndex = svIdx;
    notifyListeners();

    try {
      await _videoController?.dispose();
      _chewieController?.dispose();

      final headers = {
        'Referer': Uri.parse(url).origin,
        'Origin': Uri.parse(url).origin,
      };
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: headers);
      await _videoController!.initialize();

      // Tự động tua đến vị trí cũ nếu có
      if (startAt != null && startAt < _videoController!.value.duration) {
        await _videoController!.seekTo(startAt);
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        showControls: true,
        placeholder: Container(color: Colors.black),
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
      );
      
      _videoWidget = Chewie(controller: _chewieController!);
      _isLoading = false;
      
      _startProgressTimer();
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Không thể phát video. Vui lòng kiểm tra kết nối.\n$e";
    }

    notifyListeners();
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveProgress();
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _saveProgress() {
    if (_videoController != null && _videoController!.value.isInitialized && _currentMovie != null) {
      final position = _videoController!.value.position.inSeconds;
      final duration = _videoController!.value.duration.inSeconds;

      if (position > 0 && duration > 0) {
        _movieProvider?.addToHistory(
          _currentMovie!,
          position: position,
          duration: duration,
          epName: _currentEpisodeName,
        );

        // Affinity tracking — 90% completion triggers affinity bump (once per episode)
        final percent = position / duration;
        final key = '${_currentMovie!.slug}_$_currentEpisodeName';
        if (percent >= 0.9 && !_watchedMilestone90.contains(key)) {
          _watchedMilestone90.add(key);
          _recommendationService.updateAffinityFromWatch(_currentMovie!, percent);
        }
      }
    }
  }

  void toggleExpand(bool expand) {
    _isExpanded = expand;
    if (!expand) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    notifyListeners();
  }

  void closePlayer() {
    _saveProgress(); // Lưu lần cuối trước khi đóng
    _stopProgressTimer();

    // Clear 90% milestone for this movie so re-watch triggers affinity again
    if (_currentMovie != null) {
      _watchedMilestone90.removeWhere((k) => k.startsWith(_currentMovie!.slug));
    }

    _videoController?.pause();
    _videoController?.dispose();
    _chewieController?.dispose();
    _videoController = null;
    _chewieController = null;
    _videoWidget = null;
    _currentMovie = null;
    _isMiniPlayerActive = false;
    _isExpanded = false;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    notifyListeners();
  }

  @override
  void dispose() {
    _stopProgressTimer();
    super.dispose();
  }
}
