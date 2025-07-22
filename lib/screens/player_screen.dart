import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

class PlayerScreen extends StatefulWidget {
  final String? filePath;
  final String? streamUrl;
  final String? title;
  final List<String>? allowedUrls;

  const PlayerScreen.local({super.key, required this.filePath, this.title}) : streamUrl = null, allowedUrls = null;
  const PlayerScreen.web({super.key, required this.streamUrl, this.title, this.allowedUrls}) : filePath = null;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _webViewError = false;
  String? _webViewErrorMessage;
  WebViewController? _webViewController;
  bool _webViewLoaded = false;
  String? _initialUrl;
  List<String>? _allowedUrls;

  @override
  void initState() {
    super.initState();
    print('[PlayerScreen] Constructor params: filePath=${widget.filePath}, streamUrl=${widget.streamUrl}, title=${widget.title}, allowedUrls=${widget.allowedUrls}');
    if (widget.filePath != null) {
      _initializeLocalPlayer();
    } else if (widget.streamUrl != null && widget.streamUrl!.trim().isNotEmpty) {
      _isLoading = true;
      _initialUrl = widget.streamUrl;
      if (widget.allowedUrls != null && widget.allowedUrls!.isNotEmpty) {
        _allowedUrls = widget.allowedUrls;
      } else if (_initialUrl != null && _initialUrl!.isNotEmpty) {
        _allowedUrls = [_initialUrl!];
      } else {
        _allowedUrls = [];
      }
      print('[PlayerScreen] Initializing WebView for URL: \'$_initialUrl\'');
      print('[PlayerScreen] Allowed URLs: \'$_allowedUrls\'');
      if (_initialUrl != null && _allowedUrls != null && _allowedUrls!.isNotEmpty) {
        _webViewController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                print('[PlayerScreen] WebView page started: $url');
                setState(() {
                  _isLoading = true;
                  _webViewError = false;
                  _webViewErrorMessage = null;
                });
              },
              onPageFinished: (url) {
                print('[PlayerScreen] WebView page finished: $url');
                setState(() {
                  _isLoading = false;
                  _webViewLoaded = true;
                });
              },
              onWebResourceError: (error) {
                print('[PlayerScreen] WebView resource error: ${error.description}');
                setState(() {
                  _isLoading = false;
                  _webViewError = true;
                  _webViewErrorMessage = error.description;
                });
              },
              onNavigationRequest: (NavigationRequest request) {
                final url = request.url;
                final isCloudnestra = url.startsWith('https://cloudnestra.com') || url.startsWith('http://cloudnestra.com');
                final is2Embed = url.startsWith('https://2embed.cc') || url.startsWith('http://2embed.cc');
                final isMultiEmbed = url.startsWith('https://multiembed.mov') || url.startsWith('http://multiembed.mov');
                final is2EmbedWww = url.startsWith('https://www.2embed.cc') || url.startsWith('http://www.2embed.cc');
                final isStreamingNow = url.startsWith('https://streamingnow.mov') || url.startsWith('http://streamingnow.mov');
                final isYoutube = RegExp(r'^https?://([a-zA-Z0-9-]+\.)*youtube\.com/').hasMatch(url);
                if (isCloudnestra || is2Embed || is2EmbedWww || isMultiEmbed || isStreamingNow || isYoutube || (_allowedUrls != null && _allowedUrls!.contains(url))) {
                  print('[PlayerScreen] Allowed navigation to: \'${request.url}\'');
                  return NavigationDecision.navigate;
                } else {
                  print('[PlayerScreen] Blocked redirect/navigation to: \'${request.url}\'');
                  return NavigationDecision.prevent;
                }
              },
            ),
          );
        print('[PlayerScreen] About to load initial URL: $_initialUrl');
        if (_webViewController != null && _initialUrl != null) {
          _webViewController!.loadRequest(Uri.parse(_initialUrl!));
        } else {
          print('[PlayerScreen] _webViewController or _initialUrl is null, cannot load WebView.');
          setState(() {
            _isLoading = false;
            _webViewError = true;
            _webViewErrorMessage = 'No video source.';
          });
        }
        // Timeout after 15 seconds if not loaded
        Future.delayed(const Duration(seconds: 15), () {
          if (!_webViewLoaded && mounted) {
            print('[PlayerScreen] WebView timeout after 15 seconds.');
            setState(() {
              _isLoading = false;
              _webViewError = true;
              _webViewErrorMessage = 'Failed to load video. Please try again later.';
            });
          }
        });
      } else {
        print('[PlayerScreen] _initialUrl or _allowedUrls is null/empty, cannot load WebView.');
        setState(() {
          _isLoading = false;
          _webViewError = true;
          _webViewErrorMessage = 'No video source.';
        });
      }
    } else {
      print('[PlayerScreen] streamUrl is null or empty in web mode.');
      _isLoading = false;
      _webViewError = true;
      _webViewErrorMessage = 'No video source.';
    }
  }

  Future<void> _initializeLocalPlayer() async {
    if (widget.filePath == null) {
      print('[PlayerScreen] filePath is null in local mode.');
      setState(() {
        _isLoading = false;
      });
      return;
    }
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
                ? (_chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const Text('Failed to initialize video player.'))
                : (_webViewController != null && _initialUrl != null && _allowedUrls != null && _allowedUrls!.isNotEmpty)
                    ? _webViewError
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(_webViewErrorMessage ?? 'Failed to load video.',
                                  style: const TextStyle(color: Colors.red)),
                            ],
                          )
                        : WebViewWidget(controller: _webViewController!)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          SizedBox(height: 16),
                          Text('No video source.', style: TextStyle(color: Colors.red)),
                        ],
                      ),
      ),
    );
  }
} 