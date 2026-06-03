import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../models/movie.dart';
import '../../providers/movie_provider.dart';
import '../../constants/api_constants.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  int _selectedServerIndex = 0;
  int _selectedEpisodeIndex = 0;
  
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlayerInitialized = false;
  bool _isBuffering = false;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<MovieProvider>(context, listen: false)
            .loadMovieDetail(widget.movie.slug));
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer(String url) async {
    setState(() {
      _isBuffering = true;
      _isPlayerInitialized = false;
    });

    try {
      // Giải phóng controller cũ
      await _videoPlayerController?.dispose();
      _chewieController?.dispose();

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        showControls: true,
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.amber,
          handleColor: Colors.amber,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
      );

      setState(() {
        _isPlayerInitialized = true;
        _isBuffering = false;
      });
    } catch (e) {
      debugPrint("Error initializing player: $e");
      setState(() => _isBuffering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi: Trình duyệt không hỗ trợ định dạng video này hoặc lỗi kết nối.")),
        );
      }
    }
  }

  void _playCurrentEpisode(List<EpisodeServer> episodes) {
    if (episodes.isEmpty) return;
    
    final server = episodes[_selectedServerIndex];
    if (server.serverData.isEmpty) return;
    
    final episode = server.serverData[_selectedEpisodeIndex];
    _initializePlayer(episode.linkM3u8);
  }

  void _nextEpisode(List<EpisodeServer> episodes) {
    if (episodes.isEmpty) return;
    final server = episodes[_selectedServerIndex];
    if (_selectedEpisodeIndex < server.serverData.length - 1) {
      setState(() => _selectedEpisodeIndex++);
      _playCurrentEpisode(episodes);
    }
  }

  void _prevEpisode(List<EpisodeServer> episodes) {
    if (episodes.isEmpty) return;
    if (_selectedEpisodeIndex > 0) {
      setState(() => _selectedEpisodeIndex--);
      _playCurrentEpisode(episodes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Consumer<MovieProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingDetail) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          final movieInfo = provider.movieDetailData;
          if (movieInfo == null) {
            return const Center(
              child: Text("Không thể tải thông tin.", style: TextStyle(color: Colors.white)),
            );
          }

          final categories = movieInfo['category'] as List? ?? [];
          final genres = categories.map((c) => c['name']).join(', ');
          
          String actors = "Đang cập nhật";
          if (movieInfo['actor'] is List) {
             actors = (movieInfo['actor'] as List).join(', ');
          }
          
          String directors = "Đang cập nhật";
          if (movieInfo['director'] is List) {
             directors = (movieInfo['director'] as List).join(', ');
          }

          final episodeTotal = movieInfo['episode_total'] ?? "??";

          return Column(
            children: [
              _buildPlayerHeader(context, movieInfo, provider.episodes),
              Expanded(
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildMovieInfoSection(movieInfo, provider, genres),
                      ),
                      const TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: Colors.amber,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelColor: Colors.amber,
                        unselectedLabelColor: Colors.grey,
                        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        tabs: [
                          Tab(text: "Giới thiệu"),
                          Tab(text: "Tập phim"),
                          Tab(text: "Đánh giá"),
                          Tab(text: "Liên quan"),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildOverviewTab(movieInfo, directors, actors, episodeTotal),
                            _buildEpisodesTab(provider),
                            const Center(child: Text("Chưa có đánh giá", style: TextStyle(color: Colors.white70))),
                            const Center(child: Text("Tính năng đang phát triển", style: TextStyle(color: Colors.white70))),
                          ],
                        ),
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

  Widget _buildPlayerHeader(BuildContext context, Map<String, dynamic> movieInfo, List<EpisodeServer> episodes) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // Nội dung chính: Video hoặc Ảnh bìa
          if (_isPlayerInitialized && _chewieController != null)
            Chewie(controller: _chewieController!)
          else
            GestureDetector(
              onTap: _isBuffering ? null : () => _playCurrentEpisode(episodes),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    ApiConstants.getImageUrl(movieInfo['thumb_url'] ?? ""),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                  ),
                  Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  Center(
                    child: _isBuffering 
                      ? const CircularProgressIndicator(color: Colors.amber)
                      : Container(
                          padding: const EdgeInsets.all(15),
                          decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded, size: 45, color: Colors.black),
                        ),
                  ),
                ],
              ),
            ),
            
          // Nút Back (Luôn ở trên cùng)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
          ),
          
          // Nút Actions
          if (!_isPlayerInitialized)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    context.watch<MovieProvider>().isFavorite(widget.movie.slug) 
                        ? Icons.favorite 
                        : Icons.favorite_border,
                    color: Colors.white,
                  ),
                  onPressed: () => context.read<MovieProvider>().toggleFavorite(widget.movie),
                ),
                IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white), onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieInfoSection(Map<String, dynamic> movieInfo, MovieProvider provider, String genres) {
    final episodes = provider.episodes;
    final server = episodes.isNotEmpty ? episodes[_selectedServerIndex] : null;
    final currentEpName = (server != null && server.serverData.isNotEmpty) 
        ? server.serverData[_selectedEpisodeIndex].name 
        : "1";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                movieInfo['name'] ?? "",
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Tập $currentEpName/${movieInfo['episode_total'] ?? "?"}",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            const Text("8.8", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 15),
            Text(
              "${movieInfo['year']}  •  ${genres.split(',').first}  •  ${movieInfo['time'] ?? '45 phút'}",
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _selectedEpisodeIndex > 0 ? () => _prevEpisode(episodes) : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("← Tập trước", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: (server != null && _selectedEpisodeIndex < server.serverData.length - 1) 
                    ? () => _nextEpisode(episodes) 
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Tập tiếp →", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> movieInfo, String directors, String actors, dynamic episodeTotal) {
    final String content = movieInfo['content']?.replaceAll(RegExp(r'<[^>]*>'), '') ?? "Không có mô tả.";
    final bool isLongContent = content.length > 150;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                maxLines: _isDescriptionExpanded ? null : 4,
                overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 15),
              ),
              if (isLongContent)
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        _isDescriptionExpanded ? "Thu gọn" : "Xem thêm...",
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow("Đạo diễn:", directors),
          _buildDetailRow("Diễn viên:", actors),
          _buildDetailRow("Số tập:", "$episodeTotal tập"),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (movieInfo['category'] as List? ?? []).map((cat) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(cat['name'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text("2.1M lượt xem", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesTab(MovieProvider provider) {
    if (provider.episodes.isEmpty) {
      return const Center(child: Text("Đang cập nhật tập phim...", style: TextStyle(color: Colors.white38)));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.episodes.length,
      itemBuilder: (context, sIndex) {
        final server = provider.episodes[sIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.episodes.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  "Server: ${server.serverName}",
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                ),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: server.serverData.length,
              itemBuilder: (context, eIndex) {
                final episode = server.serverData[eIndex];
                final bool isSelected = _selectedEpisodeIndex == eIndex && _selectedServerIndex == sIndex;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedServerIndex = sIndex;
                      _selectedEpisodeIndex = eIndex;
                    });
                    _playCurrentEpisode(provider.episodes);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.amber : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      episode.name,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
