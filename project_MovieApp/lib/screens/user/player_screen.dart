import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class PlayerScreen extends StatefulWidget {

  final String videoUrl;
  final String title;

  const PlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<PlayerScreen> createState() =>
      _PlayerScreenState();
}

class _PlayerScreenState
    extends State<PlayerScreen> {

  late VideoPlayerController
  videoPlayerController;

  ChewieController? chewieController;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    initializePlayer();
  }

  Future<void> initializePlayer() async {
    final url = widget.videoUrl;
    final headers = {
      'Referer': Uri.parse(url).origin,
      'Origin': Uri.parse(url).origin,
    };
    videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
    );

    await videoPlayerController.initialize();

    chewieController = ChewieController(
      videoPlayerController:
      videoPlayerController,

      autoPlay: true,
      looping: false,

      allowFullScreen: true,
      allowMuting: true,
    );

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {

    videoPlayerController.dispose();
    chewieController?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
      ),

      body: Center(

        child: isLoading
            ? const CircularProgressIndicator()

            : Chewie(
          controller:
          chewieController!,
        ),
      ),
    );
  }
}