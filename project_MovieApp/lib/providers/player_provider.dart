import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/movie.dart';

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

  Future<void> setVideo(Movie movie, String url, String episodeName, {int epIdx = 0, int svIdx = 0}) async {
    if (_currentMovie?.slug == movie.slug && _currentEpisodeName == episodeName) {
      _isExpanded = true;
      notifyListeners();
      return;
    }

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

      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        // TỰ ĐỘNG LẤY TỈ LỆ CỦA VIDEO, KHÔNG ÉP 16/9
        aspectRatio: _videoController!.value.aspectRatio,
        showControls: true,
        placeholder: Container(color: Colors.black),
        // CHO PHÉP XOAY NGANG KHI VÀO FULLSCREEN NATIVE
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        // LUÔN TRẢ VỀ DỌC KHI THOÁT FULLSCREEN NATIVE
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
      );
      
      _videoWidget = Chewie(controller: _chewieController!);
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Không thể phát video. Vui lòng kiểm tra kết nối.";
    }

    notifyListeners();
  }

  void toggleExpand(bool expand) {
    _isExpanded = expand;
    // QUAN TRỌNG: Nếu thu nhỏ về Mini Player, ép màn hình về hướng dọc ngay lập tức
    if (!expand) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    notifyListeners();
  }

  void closePlayer() {
    _videoController?.pause();
    _videoController?.dispose();
    _chewieController?.dispose();
    _videoController = null;
    _chewieController = null;
    _videoWidget = null;
    _currentMovie = null;
    _isMiniPlayerActive = false;
    _isExpanded = false;
    
    // Đảm bảo app về hướng dọc khi tắt player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    notifyListeners();
  }
}
