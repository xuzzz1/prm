import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/player_provider.dart';
import '../screens/user/movie_detail_screen.dart';
import '../main.dart'; // navigatorKey

class MiniPlayerWidget extends StatefulWidget {
  const MiniPlayerWidget({super.key});

  @override
  State<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends State<MiniPlayerWidget> {
  double _dragY = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        if (!player.isMiniPlayerActive || player.currentMovie == null) {
          return const SizedBox.shrink();
        }

        if (isLandscape && player.isExpanded) {
           return const SizedBox.shrink();
        }

        const double miniWidth = 160; 
        const double miniHeight = 90; 
        const double margin = 12;
        final double bottomNavHeight = 60 + bottomPadding;

        double dragPercentage = (_dragY / (size.height * 0.4)).clamp(0.0, 1.0);
        if (!player.isExpanded) dragPercentage = 1.0;

        double currentWidth = size.width - (size.width - miniWidth) * dragPercentage;
        double currentHeight = (size.width / (16 / 9)) - ((size.width / (16 / 9)) - miniHeight) * dragPercentage;
        
        double targetTop = size.height - currentHeight - bottomNavHeight - margin;
        double targetLeft = size.width - currentWidth - margin;

        double top = player.isExpanded ? _dragY : targetTop;
        double left = player.isExpanded ? (size.width - currentWidth) * dragPercentage : targetLeft;

        return AnimatedPositioned(
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
          top: top,
          left: left,
          width: currentWidth,
          height: currentHeight,
          child: Listener(
            // DÙNG Listener để không chặn Tap của Chewie
            onPointerMove: (event) {
              if (!player.isExpanded) return;
              setState(() {
                _isDragging = true;
                _dragY += event.delta.dy;
                if (_dragY < 0) _dragY = 0;
              });
            },
            onPointerUp: (event) {
              if (!player.isExpanded) return;
              setState(() => _isDragging = false);
              
              if (_dragY > size.height * 0.15) {
                player.toggleExpand(false);
                setState(() => _dragY = 0);
                if (navigatorKey.currentState?.canPop() ?? false) {
                  navigatorKey.currentState?.pop();
                }
              } else {
                setState(() => _dragY = 0);
              }
            },
            child: GestureDetector(
              // Chỉ bắt Tap khi đang là Mini Player
              onTap: player.isExpanded ? null : () {
                player.toggleExpand(true);
                navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (context) => MovieDetailScreen(movie: player.currentMovie!)),
                );
              },
              child: Material(
                elevation: player.isExpanded ? 0 : 16,
                color: Colors.black,
                borderRadius: BorderRadius.circular(dragPercentage * 16),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // VIDEO
                    Positioned.fill(
                      child: (!player.isExpanded && player.videoController != null)
                          ? VideoPlayer(player.videoController!)
                          : (player.videoWidget ?? const Center(child: CircularProgressIndicator(color: Colors.amber))),
                    ),

                    // NÚT ĐÓNG (Chỉ hiện khi Mini)
                    if (!player.isExpanded)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black26,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              onPressed: () => player.closePlayer(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
