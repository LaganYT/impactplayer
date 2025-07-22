import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

class PlayerScreen extends StatefulWidget {
  final String? filePath;
  final String? streamUrl;
  final String? title;

  const PlayerScreen.local({super.key, required this.filePath, this.title}) : streamUrl = null;
  const PlayerScreen.web({super.key, required this.streamUrl, this.title}) : filePath = null;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.filePath != null) {
      _initializeLocalPlayer();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _initializeLocalPlayer() async {
    _videoController = VideoPlayerController.file(File(widget.filePath!));
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.deepPurple,
        handleColor: Colors.deepPurpleAccent,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.deepPurple.shade100,
      ),
      allowPlaybackSpeedChanging: true,
      showControlsOnInitialize: true,
    );
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? (widget.filePath?.split('/').last ?? 'Player');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : widget.filePath != null
                ? Chewie(controller: _chewieController!)
                : widget.streamUrl != null
                    ? WebViewWidget(
                        controller: WebViewController()
                          ..setJavaScriptMode(JavaScriptMode.unrestricted)
                          ..loadRequest(Uri.parse(widget.streamUrl!)),
                      )
                    : const Text('No video source.'),
      ),
    );
  }
} 